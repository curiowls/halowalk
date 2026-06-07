# HaloWalk CloudKit Sync Architecture

**Status:** Build C in progress: owner solo sync plus CKShare invite/accept for multi-participant families.
**Owner:** anyone touching `HaloCloudSync`, `CloudKitSchema`, or the local stores' `upsertFromCloud` paths.

Read this before changing the schema, the sync engine, or anything that mutates FamilyStore / HubStore / PresenceStore.

---

## The model

- **Container:** `iCloud.com.halowalk.guardian`
- **Zone:** one custom zone `HaloFamily` per family. Owners write it in their private database; accepted participants read/write the shared copy from `sharedCloudDatabase`.
- **Engine:** `CKSyncEngine` (iOS 17+). It owns change tokens, batching, retry/backoff, offline queueing. We only supply (a) which record IDs changed and (b) how to merge what comes back.
- **Cache:** UserDefaults stays the offline cache / first-paint. CloudKit is the source of truth when reachable.
- **Build B scope:** owner-only. Data round-trips across the same iCloud account's devices and survives reinstall.
- **Build C scope:** `CKShare` on the `Family` root record; invite/accept through Apple's CloudKit sharing UI; participant → Member setup; all guardians watch all watched/sharing members.

## Record types & keys

All records live in the `HaloFamily` zone. Record names are derived from model UUIDs so re-saving overwrites instead of duplicating.

| Type | Record name | Notes |
|---|---|---|
| `Family` | `family_<uuid>` | The CKShare root in Build C |
| `Member` | `member_<uuid>` | carries `appleUserId` and `locationSharingEnabled` for participant matching/privacy |
| `Relationship` | `rel_<uuid>` | the watch graph (one-way & two-way) |
| `Device` | `device_<uuid>` | |
| `Hub` | `hub_<uuid>` | |
| `LocationReading` | `reading_<memberUUID>_<deviceUUID>` | **overwrite per (member,device)** — never appended, can't explode |

Conversion lives entirely in `CloudKitSchema.swift`. `HaloCloudSync` never touches CKRecord fields directly.

## Sync-loop guard (important)

`HaloCloudSync` observes the stores' `@Published` collections with **no debounce**. This is deliberate:

- `@Published` sinks fire **synchronously** on the same call stack as the mutation.
- When the mutation is a remote merge (inside `apply()`, which sets `applyingRemoteChanges = true`), the `enqueue*` methods see the flag and skip — so a downloaded record doesn't bounce straight back up.
- A debounce would delay the sink until *after* the flag resets, breaking the guard and creating an upload/download ping-pong.
- `CKSyncEngine` batches the actual network sends itself, so eager enqueueing is cheap (it just adds deduped pending record IDs to engine state).

**Do not add a debounce to the store observers.** If you need coalescing, it belongs inside the engine, not before the guard.

## Conflict resolution

Last-writer-wins, with one hard rule: **a fetched server record never overwrites a local record that has an unsent pending change.** `apply()` skips any fetched record whose `recordID` is in `engine.state.pendingRecordZoneChanges` (as a `.saveRecord`). Without this, editing an *existing* record (e.g. changing your avatar on the Member record) loses the edit: a routine fetch returns the stale server copy and stomps the local edit before the queued `saveRecord` sends — then the save materializes the stomped value. New records (new UUID, no server copy) were unaffected, which is why the Build 30/31 symptom was "avatar reverts but new hubs stick."

Beyond that: `upsertFromCloud(...)` replaces the local record wholesale; for LocationReading newest-timestamp naturally wins; `Family.memberIds` guards against an empty cloud value clobbering a populated local one during bootstrap races.

## CKRecord system fields (the change-tag cache) — DO NOT REMOVE

CloudKit uses optimistic concurrency. Updating an existing server record requires sending a `CKRecord` that carries the server's current `recordChangeTag`. A freshly-built `CKRecord(recordType:recordID:)` has **no tag**: the first save (a create) succeeds, but every subsequent update is rejected with `serverRecordChanged` and the edit is silently lost. Real-world symptom we hit: "yesterday's avatar change stuck, today's didn't"; new hubs always worked because creates don't need a tag.

`HaloCloudSync` keeps a `systemFields` cache (zone + recordName → archived `CKRecord.encodeSystemFields`), persisted to `halowalk.cksync.systemFields.v2`:

- **`materialize()`** starts from the cached record (carrying the tag) and copies current data fields onto it — never sends a virgin record for an existing object.
- The cache is refreshed from every authoritative server record: on fetch (`fetchedRecordZoneChanges`, even for records we skip applying due to a pending local edit) and on every successful save (`sentRecordZoneChanges.savedRecords`).
- `serverRecordChanged` failures adopt the error's `serverRecord` tag and re-queue the save (client-wins last-writer).

If you ever refactor `CloudKitSchema.record(for:)` or `materialize`, preserve this. Sending tagless records for existing objects is the single most likely way to silently break sync again.

## Lifecycle

`HaloCloudSync.shared.start()` is called from `HaloWalkApp.deferredActivations()` behind the `halowalk.safe.cloudSync` kill-switch (Privacy & permissions → Diagnostics), like every other heavy subsystem. It:

1. checks `CKContainer.accountStatus()` — bails if iCloud unavailable
2. restores private-owner or shared-participant scope
3. boots the engine with the persisted state serialization for that database scope
4. enqueues a `saveZone` for `HaloFamily` only for private owners
5. wires the store observers
6. pushes the entire local state up + fetches anything already in the cloud

State serialization (`CKSyncEngine.State.Serialization`, a `Codable`) is persisted separately for private and shared scopes via the `.stateUpdate` event.

## Sharing flow

1. The owner opens **Family members → Invite family member**.
2. `UICloudSharingController` asks `HaloCloudSync` to create or fetch the family `CKShare`.
3. The invited person accepts the CloudKit link. iOS launches HaloWalk through `CKSharingSupported` and `HaloWalkAppDelegate.application(_:userDidAcceptCloudKitShareWith:)`.
4. HaloWalk accepts the share, persists the shared zone owner/name, restarts sync against `sharedCloudDatabase`, and shows the join setup screen.
5. The participant signs in with Apple, chooses `Guardian`, `Watched member`, or `Both`, and explicitly chooses whether to share this iPhone's location.
6. `FamilyStore` creates/claims the participant `Member`, adds device metadata, and adds missing all-guardian/all-watched relationships.

---

## ⚠️ The Development → Production schema deploy (READ THIS)

**This is the #1 operational gotcha.** CloudKit has two environments:

- **Development** — schema auto-infers when records are first written. Used by Debug builds run from Xcode.
- **Production** — schema is **never** auto-created; an unknown record type is a hard error. **TestFlight and App Store builds use Production.**

So a TestFlight build will hit Production CloudKit, and if the schema isn't in Production yet, **every sync silently fails.**

### One-time setup (and after any schema change)

1. **Populate the Development schema.** Open `HaloWalk.xcodeproj` in Xcode, run the app once on a real device (Debug build → Development CloudKit). Sign into iCloud. Do something that writes data (the app pushes the whole local state on launch — a hub edit or avatar change is enough). This auto-infers all 6 record types + fields in Development.
   - *Verify:* CloudKit Dashboard → HaloWalk container → Schema → you should see `Family`, `Member`, `Relationship`, `Device`, `Hub`, `LocationReading`; `Member` includes `appleUserId` and `locationSharingEnabled`.
2. **Deploy to Production.** CloudKit Dashboard → **Deploy Schema Changes** → review → **Deploy**. This copies the Development schema to Production. ~30 seconds.
3. **Now TestFlight works.** Subsequent TestFlight builds hit Production where the schema now exists.

### Every time you add/rename a field or record type

Repeat: run a Debug build to infer the new schema in Development → Deploy Schema Changes to Production → then TestFlight. **Schema is additive-only in Production** — you can add fields/types but not delete or retype them. Plan field names carefully.

### Manual alternative

You can hand-create the record types + fields in the CloudKit Dashboard schema editor instead of step 1, using the field tables in `CloudKitSchema.swift`. Tedious and error-prone; the Debug-run path is strongly preferred.

---

## Testing Build C

### Owner solo regression

1. Run on device A (signed into iCloud). Add a hub / change your avatar.
2. Wait ~10 s (engine auto-syncs).
3. Delete the app from device A. Reinstall (TestFlight or Xcode).
4. Sign in. Within a few seconds the hub / avatar should reappear — pulled from CloudKit, not UserDefaults (which was wiped with the app).
5. Cross-device: same iCloud account on an iPad → changes propagate within seconds.

If nothing syncs: check **Privacy & permissions → Diagnostics → "CloudKit sync on launch"** is on, the device is signed into iCloud, and (for TestFlight) the schema was deployed to Production.

### Multi-participant

1. Prepare two iPhones with different Apple IDs and iCloud Drive enabled.
2. Device A: run HaloWalk, complete onboarding, open **Family members → Invite family member**, and send the CloudKit invite.
3. Device B: accept the invite link, open HaloWalk, complete join setup, and keep location sharing on.
4. Verify both phones show the same members, hubs, and fresh pins.
5. Device B: turn **Privacy & permissions → Share my location** off; verify B's pin disappears and its cloud readings are deleted.

---

## What's deferred

- `Trigger`, `Corridor`, `Message`/`AppNotification` records — guardian-local config / separate fan-out milestone.
- CloudKit iPhone-to-iPhone boost requests for fresher live tracking.
- Field-level dirty tracking — pilot re-enqueues whole collections on change (≤ ~30 records/family, negligible; CKSyncEngine only uploads real diffs).
- Watch CloudKit entitlement — watch syncs via WatchSync from the phone; it never talks to CloudKit directly.

## Files

- `Shared/Services/CloudKit/CloudKitSchema.swift` — container/zone/type constants + model⇄CKRecord.
- `Shared/Services/CloudKit/HaloCloudSync.swift` — the CKSyncEngine owner + delegate.
- `Shared/Services/FamilyStore.swift` — `upsertFromCloud(member:/relationship:/device:/family:)`.
- `Shared/Services/HubStore.swift` — `upsertFromCloud(hub:)`.
- `Shared/Services/PresenceStore.swift` — `ingest(_:)` (reused as the reading upsert).
- `project.yml` — entitlements (`properties:` block; xcodegen owns the .entitlements file).
