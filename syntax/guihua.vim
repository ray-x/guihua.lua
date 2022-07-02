if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "guihua"

syntax match GuihuaBufferNumber '\W\d\+'
syntax match GuihuaBufferField '\.\h\+'
syntax match GuihuaBufferField2 '->\h\+'
syn match    GuihuaBufferHex display "\<0x[a-fA-F0-9_]\+\%([iu]\%(size\|8\|16\|32\|64\|128\)\)\="
syn match    GuihuaBufferFloat       display "\<[0-9][0-9_]*\.\%([^[:cntrl:][:space:][:punct:][:digit:]]\|_\|\.\)\@!"
syn region      GuihuaBufferComment           start="//" end="$"
syntax match GuihuaBufferColon '[:|:=|<|>|"|'|{|}|\||=|&|%|\*|(|)|\[|\]|\+|\-|\/]'
syn region   GuihuaBufferString            start=+"+ skip=+\\\\\|\\"+ end=+"+
syn region   GuihuaBufferString2            start=+'+ skip=+\\\\\|\\'+ end=+'+
syntax keyword GuihuaBufferKeyword func function fn local begin end  let const defer map goto type range delete self this new delete malloc free include  def null nil as any private number module yield go typedef asm static register volatile extern const assert await with async global lambda pass import all any bytes tuple type filter format print box pub unsafe where mod trait move mut ref crate


syntax keyword GuihuaBufferCondition if else break switch throw try catch return finally default case select match in
syntax keyword GuihuaBufferLoop while for do loop continue
syntax keyword GuihuaBufferClass union enum class struct interface constexpr decltype thread thread_local friend using namespace std inline virtual export explicit class typename template instanceof extends implements public protected private abstract package super

syntax keyword GuihuaBufferType  auto int long float string var void long auto bool int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t char byte double boolean Array Boolean Date Function Number Object String RegExp

syntax keyword GuihuaBufferLogic and bitor or xor compl bitand and_eq or_eq xor_eq not not_eq true false True False None del

syntax match GuihuaBufferPath '\(\.\)*\(\/\S\+\)\{1}\.*\S*'
syntax match GuihuaRange '[<|⟪|⟬||]\(\S\+\)[⟫|⟭|>||]'
syntax match GuihuaPanelLineNr '\(:\d\+\)\{1}'
syntax match GuihuaPanelHeader '\(─\)\+\S\+\(─\)\+'
syntax match GuihuaPanelHeaderText '─\+\(\S\+\)─\+'

syntax keyword GuihuaNerdfont     𝔉 ⓕ    ﴲ    ﰮ     𝕰   ﬌             ﳅ     ∑  
syntax keyword GuihuaNerdfont2  ƒ         蘒 

hi default link GuihuaBufferNumber Number
hi default link GuihuaBufferHex Number
hi default link GuihuaBufferFloat Float
hi default link GuihuaBufferColon  Operator
hi default link GuihuaBufferPath   Title
hi default link GuihuaBufferKeyword Keyword
hi default link GuihuaBufferString String
hi default link GuihuaNerdfont Constant
hi default link GuihuaBufferString2 String
hi default link GuihuaBufferComment Comment
hi default link GuihuaBufferCondition Conditional
hi default link GuihuaBufferType Structure
hi default link GuihuaBufferLoop Repeat
hi default link GuihuaBufferClass Type
hi default link GuihuaBufferField Function
hi default link GuihuaNerdfont2 Function
hi default link GuihuaBufferField2 Function
hi default link GuihuaBufferLogic Boolean
hi default link GuihuaRange Comment
hi default link GuihuaPanelLineNr Ignore
hi default link GuihuaPanelHeader Label
hi default link GuihuaPanelHeaderText Identifier
" path match
"  /abc/def_m1/gh_a.lua   :3
" /abc/defm/gha.lua
" ./abc/def-a/gh.cpp
