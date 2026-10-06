class_name DebugKeyLocale
extends RefCounted
## 開発用：文章の代わりに、翻訳キーの名前をそのまま表示する仮の言語に切り替える。
## （例：「火球」→「CARD_FIREBALL_NAME」）長い文章でも画面が崩れないかの確認に使う。
## 翻訳ファイル（CSV）を読むため、エディタから実行した時だけ使える。

const LOCALE := "en"


static func enable() -> void:
	var translation := Translation.new()
	translation.locale = LOCALE
	for key: String in DataValidator.load_translation_texts(DataValidator.LOCALIZATION_DIR):
		translation.add_message(key, key)
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(LOCALE)
