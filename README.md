<img src="/Assets/McKey-1024x1024@1x.png" alt="McKey icon" width="200">

# MćKey – UniKey for macOS
### Bộ gõ tiếng Việt trên macOS không-IME dựa trên mã nguồn UniKey.<br />Non-IME macOS Vietnamese input application based on UniKey.

- **Không lặp ký tự khi gõ `delete`** – Bạn từng bấm xoá văn bản, mà toàn bộ phần
  gạch dưới lặp đi lặp lạilạilạilạilạilại mỗi cú nhấp? Đây là lỗi IME (Input Method Editor) của macOS; 
  MćKey không dùng IME mà dùng macOS Accessibility API, tạo cảm giác gõ giống UniKey trên Windows.


- **No duplication-on-`delete` in text fields.** Ever pressed delete key on a text field only for the text 
  to duplicateduplicateduplicate on every delete. This is a macOS IME bug; MćKey bypass IME and
  use the macOS Accessibility API for authentic UniKey on Windows like feel.

<img src="/Assets/screenshot-menu_bar.png" alt="McKey Menu Bar Screenshot" width="500">
<img src="/Assets/screenshot-window.png" alt="McKey Menu Bar Screenshot" width="500">

## How it works

A `CGEventTap` intercepts each keystroke and runs it through a Vietnamese engine
(Telex / VNI) that maintains the current syllable.

- If the keystroke just appends a character that is identical to what you typed
  (normal letter, no accent change), the event passes through natively. To the
  app, including its inline autocomplete, it looks exactly like a human typing.
- When a key adds/changes a diacritic (e.g. `s` → sắc tone, `aa` → â), the engine
  computes the new syllable, then deletes **only the changed suffix** (synthetic
  backspaces) and re-injects the replacement as a single atomic Unicode insert.

Tone placement is ported from UniKey's `getTonePosition()`, so accents land on the
correct vowel: `hòa`, `hoàn`, `thúy`, `người`, `cuộc`, `khỏe`, `tiếng`, `Việt`…

## Contribution

Always welcome!

## Attribution

[UniKey for Microsoft Windows](https://unikey.org) © Pham Kim Long, adapted under GPL license.<br />A faithful rewrite from C++ to native Swift for macOS.

## License

GNU General Public License

