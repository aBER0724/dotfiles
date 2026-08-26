#!/usr/bin/env python3
"""Apply librime-lua 5.4 compatibility fixes to the installed custom config."""
from pathlib import Path

root = Path.home() / ".local/share/fcitx5/rime/lua"

replacements = {
    "search.lua": [
        ("            i = i + 1\n", ""),
    ],
    "auxCode_filter.lua": [
        (
            '''    for line in file:lines() do
        line = line:match("[^\\r\\n]+") -- 去掉換行符，不然 value 是帶著 \\n 的
        local key, value = line:match("([^=]+)=(.+)") -- 分割 = 左右的變數
''',
            '''    for line in file:lines() do
        local clean_line = line:match("[^\\r\\n]+") -- 去掉换行符
        local key, value = clean_line:match("([^=]+)=(.+)") -- 分割 = 左右的变量
''',
        ),
        (
            '''                    cand = ShadowCandidate(originalCand, originalCand.type, shadowText,
                        originalCand.comment .. shadowComment .. '(' .. codeComment .. ')')
''',
            '''                    local annotatedCand = ShadowCandidate(originalCand, originalCand.type, shadowText,
                        originalCand.comment .. shadowComment .. '(' .. codeComment .. ')')
                    yield(annotatedCand)
                    goto continue
''',
        ),
        (
            '''            else
                -- 待选项字词 没有 匹配到当前的辅助码，插入到列表中，最后插入到候选框里( 获得靠后的位置 )
''',
            '''            else
                -- 待选项字词 没有匹配到当前的辅助码
''',
        ),
        (
            '''                -- 更新逻辑：没有匹配上就不出现再候选框里，提升性能
            end
        end
''',
            '''                -- 更新逻辑：没有匹配上就不出现再候选框里，提升性能
            end
            ::continue::
        end
''',
        ),
    ],
    "cn_en_spacer.lua": [
        (
            '''        if is_mixed_cn_en_num(cand.text) then
            cand = cand:to_shadow_candidate(cand.type, add_spaces(cand.text), cand.comment)
        end
        yield(cand)
''',
            '''        if is_mixed_cn_en_num(cand.text) then
            local spaced_cand = cand:to_shadow_candidate(cand.type, add_spaces(cand.text), cand.comment)
            yield(spaced_cand)
        else
            yield(cand)
        end
''',
        ),
    ],
    "en_spacer.lua": [
        (
            '''        if cand.text:match( '^[%a\\']+[%a\\']*$' ) and latest_text and #latest_text > 0 and
            latest_text:find( '^ ?[%a\\']+[%a\\']*$' ) then
            cand = cand:to_shadow_candidate( 'en_spacer', cand.text:gsub( '(%a+\\'?%a*)', ' %1' ), cand.comment )
        end
        yield( cand )
''',
            '''        if cand.text:match( '^[%a\\']+[%a\\']*$' ) and latest_text and #latest_text > 0 and
            latest_text:find( '^ ?[%a\\']+[%a\\']*$' ) then
            local spaced_cand = cand:to_shadow_candidate( 'en_spacer', cand.text:gsub( '(%a+\\'?%a*)', ' %1' ), cand.comment )
            yield( spaced_cand )
        else
            yield( cand )
        end
''',
        ),
    ],
}

for name, edits in replacements.items():
    path = root / name
    if not path.exists():
        continue
    text = path.read_text()
    changed = False
    for old, new in edits:
        if old in text:
            text = text.replace(old, new, 1)
            changed = True
    if changed:
        path.write_text(text)
