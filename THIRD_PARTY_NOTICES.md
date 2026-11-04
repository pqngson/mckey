# Third-party notices

## PHTV Vietnamese input engine

McKey includes Swift engine and dictionary code derived from `pqngson/PHTV` at source revision `0a42ef4` (2026-11-03), including the core, Vietnamese tables, text output encoder, dictionary trie and detector bridges, custom consonant helper, engine character map, and English/Vietnamese dictionary data. Copyright © 2026 Phạm Hùng Tiến. These portions are licensed under the GNU Affero General Public License version 3; see [LICENSE-AGPL-3.0.txt](McKey/LICENSE-AGPL-3.0.txt). The original project is [PHTV](https://github.com/PhamHungTien/PHTV).

The PHTV-derived code is adapted for McKey's in-process engine API. Macro services and user custom dictionary services are not included. PHTV credits [UniKey](https://unikey.org/) by Phạm Kim Long and [OpenKey](https://github.com/tuyenvm/OpenKey) by Mai Vũ Tuyên for Vietnamese engine work; those upstream attributions are preserved here.

## UniKey

McKey's UniKey-derived code is licensed under the GNU General Public License version 3. UniKey for Microsoft Windows is © Pham Kim Long. See the attribution and license information in [README.md](README.md) and [LICENSE.md](LICENSE.md).
