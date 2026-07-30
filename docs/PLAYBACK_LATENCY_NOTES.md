# Playback latency / buffer experiments

## Fallback checkpoint (committed before UDP + balanced buffer)

**Commit message tag:** full demuxer buffer experiment  

State at this checkpoint:

- Live demuxer `bufferSize`: **32 MB** (media_kit default)
- **Video** settings button: **hidden**
- Android live RTSP: no `rtsp_transport` query → **UDP**
- iOS live RTSP: `?rtsp_transport=tcp` → **TCP** (defensive legacy)
- Recording (FFmpeg): still **TCP**
- Observed: no stutter; latency a bit over **1 s** (hardware target ~**0.8 s**);
  clarity little changed on iOS; Fold 5 looked clear

To restore this checkpoint:

```bash
git log --oneline --grep='full demuxer buffer'
git checkout <that-commit> -- lib/src/features/viewer/viewer_screen.dart
# or: git revert <later-commit>
```

## Next experiment (after this checkpoint)

- iOS live: same as Android (**no TCP query** → UDP)
- Demuxer buffer: **balanced ~4 MB** (between old 256 KB–1 MB and 32 MB)
- Keep Video settings button hidden for now

Applied on branch tip after `17cd334` (or search commit message for
“UDP live on iOS”). Fallback remains the checkpoint above.
