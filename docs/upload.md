# Upload

Athletes only. The Upload tab is hidden entirely for recruiters and brands.

## How it works

Four steps on one screen, advanced by state rather than navigation:

1. **Pick** — choose a video from the photo library.
2. **Trim** — if the clip is longer than the limit, scrub to a segment. The
   trimmed range is exported to a new file.
3. **Tag** — pick a category (Tape or Culture/NIL), add tags, write a caption.
4. **Publish** — upload the video file to Firebase Storage, generate and upload
   a thumbnail, then `POST /api/videos` with the resulting URLs.

The file goes to Firebase Storage directly from the device; the backend only
ever stores metadata and the download URLs. (`UploadController` and
`S3Service` are a legacy presigned-URL path that mobile clients don't use.)

While publishing, the form is covered by an overlay showing the current phase
and progress, with a cancel button. The form stays in the view tree but is
non-interactive, so publish can't be double-tapped.

On success the app posts `.tapeVideoPublished`, which makes the feed refresh so
the new clip appears without a relaunch.

### Tags

Tags come from `TagCatalog`, a bundled list grouped by sport, position, and
play type. Position and play-type chips are narrowed to the uploader's sport,
so a football player isn't scrolling past basketball terms. The list is bundled
rather than fetched because it is small, changes rarely, and an athlete
mid-upload shouldn't wait on a network round trip to find out what "QB" means.

---

## Files

### iOS

| File | What it does |
|---|---|
| `Tape/Views/Upload/UploadView.swift` | The upload flow container: photo picker, step routing, and the success alert |
| `Tape/Views/Upload/VideoTrimmerView.swift` | Scrubbing UI for selecting the segment to keep, with a live preview |
| `Tape/Views/Upload/TagSelectionView.swift` | Category picker, caption field, tag chips, publish button, and the publishing overlay; also defines the `FlowLayout` used for wrapping chips |
| `Tape/ViewModels/UploadViewModel.swift` | The whole pipeline: trim and export, upload with progress, thumbnail generation, publish, and cancellation |
| `Tape/Services/Storage/StorageService.swift` | `StorageServiceProtocol` and its mock: upload a file, report progress, return a download URL |
| `Tape/Services/Storage/FirebaseStorageService.swift` | Firebase Storage implementation with progress reporting and cancellation |
| `Tape/Support/TagCatalog.swift` | The tag catalog and its per-sport narrowing |
| `Tape/Components/AsyncVideoThumbnail.swift` | Generates a still from a video when no thumbnail exists |

### Backend

| File | What it does |
|---|---|
| `controller/VideoController.java` | `POST /api/videos` — see [feed.md](feed.md) for the rest of this controller |
| `dto/VideoPublishRequest.java` | Publish payload: video URL, thumbnail URL, category, tags, caption |
| `controller/UploadController.java` | Legacy S3 presigned-URL endpoint; unused by the iOS app |
| `service/S3Service.java` | Generates presigned S3 URLs, or placeholders when AWS credentials are absent |
| `config/S3Config.java` | Creates the S3 client bean only when access keys are configured |

---

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/videos` | Publish clip metadata after the file is in Firebase Storage |

The `athleteId` field in the body is ignored — the authenticated caller is
always the owner, and they must have the `ATHLETE` role.
