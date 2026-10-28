# Dictionary sources

## UI styling

Update 2 includes generated Tailwind CSS **v3.4.17** from the user-supplied HTML prototype. The upstream MIT license notice remains in the compiled stylesheet. Project and license: https://github.com/tailwindlabs/tailwindcss/tree/v3.4.17

ThaiChatBridge Wide Dictionary V1 includes filtered Thai words and syllables from PyThaiNLP:

- Project: https://github.com/PyThaiNLP/pythainlp
- Pinned commit: `726055a5dc6e83d5c17c39dae80ddf0f8c914f4d`
- Files: `pythainlp/corpus/words_th.txt`, `pythainlp/corpus/syllables_th.txt`
- Corpus license: **CC0-1.0**, declared for these exact lists in https://github.com/PyThaiNLP/pythainlp/blob/726055a5dc6e83d5c17c39dae80ddf0f8c914f4d/pythainlp/corpus/corpus_license.md
- License text: https://creativecommons.org/publicdomain/zero/1.0/legalcode

CP874-encodable Thai-only entries are filtered, deduplicated, combined with the frozen V2 dictionary and generated consonant/vowel/tone byte patterns. Generated patterns are compression byte sequences, not necessarily valid syllables. No PyThaiNLP runtime is needed. Original bytes are preserved without normalization or spelling correction.
