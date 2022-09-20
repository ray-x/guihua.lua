if exists("b:current_syntax")
  finish
endif
let b:current_syntax = 'guihua'

syntax match GuihuaBufferNumber "\<-\=\(0\|[1-9]_\?\(\d\|\d\+_\?\d\+\)*\)\%([Ee][-+]\=\d\+\)\=\>"
syn match    GuihuaBufferHex display "\<0x[a-fA-F0-9_]\+\%([iu]\%(size\|8\|16\|32\|64\|128\)\)\="
syn match    GuihuaBufferFloat       display "\<[0-9][0-9_]*\.\%([^[:cntrl:][:space:][:punct:][:digit:]]\|_\|\.\)\@!"
syntax match GuihuaBufferField '\.\h\+'
syntax match GuihuaBufferField2 '->\h\+'
syn region      GuihuaBufferComment           start="//" end="$"
syntax match GuihuaBufferColon '[:|:=|<|>|"|'|{|}|\||=|&|%|\*|(|)|\[|\]|\+|\-|\/]'
syn region   GuihuaBufferString            start=+"+ skip=+\\\\\|\\"+ end=+"+
syn region   GuihuaBufferString2           start=+b"+ skip=+\\\\\|\\"+ end=+"+
syn region   GuihuaBufferString3           start='b\?r\z(#*\)"' end='"\z1'
" syn match    GuihuaBufferRustLftm           "[<|&]'"
syntax keyword GuihuaBufferKeyword  type struct enum union as break filter format print box pub unsafe where mod trait move mut ref crate extern fn in impl let pub return super unsafe where use move static const


syntax keyword GuihuaBufferCondition if else break switch throw try catch return finally default case select match in
syntax keyword GuihuaBufferLoop while for do loop continue
syntax keyword GuihuaBufferClass union enum class struct interface constexpr decltype thread thread_local friend using namespace std inline virtual export explicit class typename template instanceof extends implements public protected private abstract package super self

syntax keyword GuihuaBufferType   isize usize char bool u8 u16 u32 u64 u128 f32 f64 i8 i16 i32 i64 i128 str Sel
syntax keyword GuihuaBufferLogic true false
syntax keyword GuihuaBufferFunction  Copy Send Sized Sync
syntax match GuihuaBufferPath '\(\.\)*\(\/\S\+\)\{1}\.*\S*'

syntax keyword GuihuaNerdfont     𝔉 ⓕ    ﴲ    ﰮ     𝕰   ﬌             ﳅ     ∑   
syntax keyword GuihuaNerdfont2  ƒ          蘒 

hi default link GuihuaBufferNumber Number
hi default link GuihuaBufferHex Number
hi default link GuihuaBufferFloat Float
hi default link GuihuaBufferColon  Operator
hi default link GuihuaBufferPath   Title
hi default link GuihuaBufferKeyword Keyword
hi default link GuihuaBufferString String
hi default link GuihuaBufferString2 String
hi default link GuihuaBufferString3 String
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
hi default link GuihuaBufferFunction Function
hi default link GuihuaBufferLogic Boolean
hi default link GuihuaRange Comment
hi default link GuihuaPanelLineNr LineNr
hi default link GuihuaPanelHeader Label
hi default link GuihuaPanelHeaderText Identifier
" path match
"  /abc/def_m1/gh_a.lua   :3
" /abc/defm/gha.lua
" ./abc/def-a/gh.cpp
