#!/bin/sh
set -e

echo "Feature 'confluence-cli' を有効化しています"

# オプション値（devcontainer CLI が環境変数として渡す: オプション id を大文字化し、
# 英数字以外を '_' に置換した名前）。
BASE_URL="${BASE_URL:-}"
USER_NAME="${USER_NAME:-}"
USER_PASSWORD="${USER_PASSWORD:-}"
INJECT_CLAUDE_DOCS="${INJECT_CLAUDE_DOCS:-true}"

# uv のツールデータを、全ユーザーが読める共有の場所に置く。これにより（非 root の）
# リモートユーザーでもインストール済み CLI を実行できる。ランチャは PATH に置く。
UV_ROOT=/opt/uv
export UV_TOOL_DIR="$UV_ROOT/tools"
export UV_PYTHON_INSTALL_DIR="$UV_ROOT/python"
export UV_TOOL_BIN_DIR=/usr/local/bin

# --- uv を用意する -----------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
    if ! command -v curl >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y --no-install-recommends curl ca-certificates
    fi
    # uv（と uvx）を PATH 上のシステム共通の場所にインストールする。インストーラに
    # シェルプロファイルを編集させない。
    export UV_INSTALL_DIR=/usr/local/bin
    export INSTALLER_NO_MODIFY_PATH=1
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

UV="$(command -v uv || echo /usr/local/bin/uv)"

# --- PyPI から CLI をインストールする ----------------------------------------
# 公開パッケージ `kci-confluence-cli` が `confluence` コマンドを提供する。
mkdir -p "$UV_ROOT"
"$UV" tool install kci-confluence-cli
# ツール環境を root 以外の全ユーザーが読める／実行できるようにする。
chmod -R a+rX "$UV_ROOT" 2>/dev/null || true

# --- オプションから環境変数を設定する ----------------------------------------
# Feature の containerEnv はオプション値を展開できないため、export をプロファイル
# スクリプト（ログインシェルが読む）に書き出し、インタラクティブな bash/zsh の rc
# からも source する。注意: これらの値はビルド時にコンテナ／イメージへ焼き込まれる。
# パスワードの扱いに注意（README 参照）。
squote() {
    # POSIX 互換の単一引用符クォート（値に単一引用符が含まれても安全）。
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

ENV_FILE=/etc/profile.d/confluence-cli.sh
if [ -n "$BASE_URL" ] || [ -n "$USER_NAME" ] || [ -n "$USER_PASSWORD" ]; then
    {
        echo '#!/bin/sh'
        echo '# confluence-cli devcontainer feature が生成。'
        if [ -n "$BASE_URL" ];      then echo "export CONFLUENCE_BASE_URL=$(squote "$BASE_URL")"; fi
        if [ -n "$USER_NAME" ];     then echo "export CONFLUENCE_USER_NAME=$(squote "$USER_NAME")"; fi
        if [ -n "$USER_PASSWORD" ]; then echo "export CONFLUENCE_USER_PASSWORD=$(squote "$USER_PASSWORD")"; fi
    } > "$ENV_FILE"
    # 全ユーザー読み取り可（通常の /etc/profile.d ファイルと同じく root 所有）。
    # ランタイムのユーザーはビルド時に確実には分からず、推測した所有者に限定すると
    # 実際のログインユーザーが異なる場合にファイルを読めず（変数が未設定になる）。
    # 値は既にユーザーのプロセスから見える環境変数で、イメージにも焼き込まれるため、
    # 644 にしても露出は広がらない。
    chmod 644 "$ENV_FILE"

    # インタラクティブな（非ログインの）bash/zsh は /etc/profile.d を読まないので、
    # それぞれのグローバル rc からも冪等に source する。
    SRC_LINE='[ -f /etc/profile.d/confluence-cli.sh ] && . /etc/profile.d/confluence-cli.sh'
    for rc in /etc/bash.bashrc /etc/zsh/zshrc; do
        if [ -f "$rc" ] && ! grep -qF 'confluence-cli.sh' "$rc"; then
            printf '\n%s\n' "$SRC_LINE" >> "$rc"
        fi
    done
fi

# --- Claude Code 向けの使い方ガイドを注入 -------------------------------------
# /etc/claude-code/CLAUDE.md は Claude Code の system(managed) レベルのメモリで、
# 全セッションで自動ロードされる。リポジトリにコミットされず、~/.claude（ホスト
# 共有領域）でもないコンテナ内専用の場所なので、ここに confluence の使い方を入れて
# おくと、エージェントが毎回 CLI の使い方を調べ直さずに済む。マーカー区切りで冪等。
if [ "$INJECT_CLAUDE_DOCS" = "true" ]; then
    CLAUDE_MD=/etc/claude-code/CLAUDE.md
    mkdir -p /etc/claude-code
    if [ -f "$CLAUDE_MD" ]; then
        sed -i '/^# BEGIN confluence-cli$/,/^# END confluence-cli$/d' "$CLAUDE_MD"
    fi
    {
        echo "# BEGIN confluence-cli"
        cat <<'DOC'
# Confluence CLI (`confluence`)

来栖川電算の Confluence (v6.15.7) を操作する CLI が `confluence` コマンドとして
インストールされています。体系は `confluence <グループ> <サブコマンド> [オプション]`。
このガイドに載っているコマンドはそのまま信頼して実行してよく、単純な閲覧・更新で
毎回 `--help` を引き直す必要はない。ガイドで触れていない引数が必要なときだけ
`confluence <グループ> <サブコマンド> --help` で確認する。

## 認証
Confluence にアクセスするコマンド（page / content / attachment）は次の環境変数で
認証します。confluence-cli feature のオプションで設定済みならそのまま使えます。
- CONFLUENCE_BASE_URL  例: https://confluence.example.com/confluence
- CONFLUENCE_USER_NAME
- CONFLUENCE_USER_PASSWORD
`local` グループ（ローカル変換）は認証不要。page_id / content_id は数値 ID で、
`.../pages/viewpage.action?pageId=123` 形式の URL なら URL 内に含まれる。一方
`.../display/<SPACE>/<Title>` 形式の URL には ID が無いので、下記「ページ URL や
タイトルから page_id を調べたい」で先に ID を解決する。

## やりたいこと → 使うコマンド
- ページ URL やタイトルから page_id を調べたい（CLI に該当サブコマンドは無い）:
  `viewpage.action?pageId=...` 形式は URL からそのまま読み取る。`display/<SPACE>/<Title>`
  形式は ID を含まないので REST で解決する（`<TITLE>` は URL エンコードする）:
  `curl -s -u "$CONFLUENCE_USER_NAME:$CONFLUENCE_USER_PASSWORD" "$CONFLUENCE_BASE_URL/rest/api/content?spaceKey=<SPACE>&title=<TITLE>"`
  応答 JSON の `results[].id` が page_id。
- キーワード・スペース・更新日などでページを全文検索したい（CLI に検索サブコマンドは
  無いので CQL を REST に投げる。式の組み立ては後述「CQL 検索の組み立て」）:
  `curl -s -u "$CONFLUENCE_USER_NAME:$CONFLUENCE_USER_PASSWORD" -G "$CONFLUENCE_BASE_URL/rest/api/content/search" --data-urlencode 'cql=<CQL式>' --data 'limit=30'`
  応答 JSON の `results[]` が該当コンテンツ。`results[].id` を page get_body 等にそのまま渡せる。
- ページ/ブログの本文を取得したい:
  `confluence page get_body -p <PAGE_ID> [--representation storage|view|...] [--pretty] [-o <出力先>]`
  既定の表現形式は storage。読むだけなら view（整形済み HTML）が読みやすく、編集して
  書き戻すなら storage を使う。--pretty で整形、-o でファイル保存。
- ページ/ブログの本文を更新したい:
  `confluence page update -p <PAGE_ID> --file <storage形式のXML> [--comment "更新理由"] [--yes]`
  指定した storage XML の内容でページを上書き。--yes で確認を省略（非対話）。
- HTML を Confluence の storage XML に変換したい（API 不要・ローカル完結）:
  `confluence local convert_html --input <入力HTML> --output <出力XML>`
  更新用の storage XML を手元で作るときに使う。
- 添付ファイルの情報を取得したい:
  `confluence attachment get -p <PAGE_ID> [--filename <名前>] [--media_type <型>] [--expand <prop>...] [-o <出力先>]`
- 添付ファイルをアップロードしたい:
  `confluence attachment create -p <PAGE_ID> (--file <ファイル>... | --dir <ディレクトリ>) [--overwrite] [--mime_type <型>] [--filename_pattern '*.png']`
  --overwrite で同名ファイルを上書き（未指定だと既存時に 400 エラー）。
- 添付ファイルを削除したい:
  `confluence attachment delete -p <PAGE_ID> [--filename <名前>] [--media_type <型>] [--purge]`
  --purge はゴミ箱からも完全削除（復元不可）。
- コンテンツ（ページ/ブログ/添付など）の情報を ID で取得したい:
  `confluence content get_by_id -c <CONTENT_ID> [--expand <prop>...] [-o <出力先>]`
  --expand で取得プロパティを指定（指定可能値は出力の `_expandable` を参照）。
- 子ページを一覧して情報を深掘りしたい（CLI に該当サブコマンドは無いので REST）:
  `curl -s -u "$CONFLUENCE_USER_NAME:$CONFLUENCE_USER_PASSWORD" "$CONFLUENCE_BASE_URL/rest/api/content/<PARENT_ID>/child/page?limit=100"`
  応答 JSON の `results[].id` / `.title` が子ページ。関連情報が子ページにあることが多い。

## CQL 検索の組み立て
上記の検索（`/rest/api/content/search`）に渡す `cql` は、次の要素を AND / OR で組み合わせる。
- 全文キーワード: `text ~ "<語>"`。複数語を OR にするなら `(text ~ "A" OR text ~ "B")`。
- コンテンツ種別: `type = page` または `type = blogpost`。
- スペース: `space = <SPACE_KEY>`（例 `space = DOC`、実在する Key のみ）。
- 親コンテンツ: `parent = <CONTENT_ID>`（実在する数値 ID のみ）。
- 最終更新日: `lastmodified <演算子> <日付>`。演算子は `=` `!=` `>` `>=` `<` `<=`。
  日付は `"yyyy/MM/dd HH:mm"` / `"yyyy-MM-dd HH:mm"` / `"yyyy/MM/dd"` / `"yyyy-MM-dd"`、
  または関数 `startOfYear()` `startOfMonth()` `startOfWeek()` `startOfDay()`（今年/今月/今週/今日の起点）。

指針:
- 「最新の〜」「2025 年以降の〜」などの時間条件は keyword に入れず、必ず `lastmodified`
  の日付条件で表す。
- `type` / `space` / `parent` は基本的に指定しない。明確な指示があるときだけ付ける。
- keyword 無しでも、`space` や `lastmodified` など条件が 1 つでもあれば検索できる。

例（`--data-urlencode 'cql=...'` に渡す式）:
- DOC スペースの今週の最新記事: `space = DOC AND lastmodified >= startOfWeek()`
- 2025 年以降の社内報: `text ~ "社内報" AND lastmodified >= "2025/01/01"`

## 典型ワークフロー
- 情報を探して読む: CQL 検索で候補を出す → `results[].id` を `page get_body` で本文取得 →
  必要なら子ページを `child/page` で辿って深掘り。
- 既存ページを書き換える: `page get_body` で現状の storage を取得 → 編集（または HTML を
  `local convert_html` で storage XML 化）→ `page update --file` で反映。
- 画像付きで更新: `attachment create` で画像をアップロード → 本文 storage XML から参照 →
  `page update`。

## 注意
- page / content / attachment は上記の環境変数認証が必要（未設定だと失敗）。local は不要。
- `attachment delete --purge` は復元不可。破壊的操作は確認のうえ実行する。
DOC
        echo "# END confluence-cli"
    } >> "$CLAUDE_MD"
    chmod 644 "$CLAUDE_MD"
    echo "confluence-cli: Claude 向けガイドを $CLAUDE_MD に注入しました"
fi

echo "confluence-cli を準備しました: 'confluence' を PATH に配置、CONFLUENCE_* は $ENV_FILE 経由で設定"
