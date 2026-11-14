insert into evaluators (evaluator_id, invite_token_hash, display_label) values
('R1', '6a802ddd6225947936bdcbfe05671a1d3ccf4c4ded111d7b808654da781e776b', 'R1'),
('R2', '9998b039ffb9c8244895666e4f40c871dd23f71e6afff22016b160ce5d498514', 'R2'),
('R3', '6179728ca9b0545cedc479d24dec96fa954d85d62695d491922ff54ae48f8a2d', 'R3')
on conflict (evaluator_id) do update set invite_token_hash = excluded.invite_token_hash, display_label = excluded.display_label;


Human mahuman, kung mag-run ka balik sa app, gamita:
flutter pub get
flutter run


FOR TOM;
CLEAN UP SPACE (WALAON TONG MGA WALAY GAMIT)
MAG HUMAN VALIDATE SA IMAGE UG VID
I-CHECK ANG EXPIRATION SA API
WALAON ANG EFFICIENTNET
REMOVE HEURISTIC ESTIMATE IN QUALITY CRITERIA RESULT
PAGDELETE SA SUPABASE FOR FREE STORAGE
ayuha ang ui sa evaluation report
Naay N/A sa media quality nga result
fix ang ai analyzer
check the ranking ang skill classification of the member usres



