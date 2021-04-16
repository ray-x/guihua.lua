if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "guihua"

syntax match GuihuaBufferNumber '\W\d\+'
syn region      GuihuaBufferComment           start="//" end="$"
syntax match GuihuaBufferColon '[:|"|'|{|}|.|\||&|%|\*|(|)|\[|\]|\+|\-|\/]'
syn region   GuihuaBufferString            start=+"+ skip=+\\\\\|\\"+ end=+"+
syn region   GuihuaBufferString2            start=+'+ skip=+\\\\\|\\'+ end=+'+
syntax keyword GuihuaBufferKeyword func function if else break for local begin end or and continue true false let auto struct class interface int long float string enum const default select case defer switch map goto var type import range return catch delete do finally try void while implements long public self this new delete malloc free include import char byte def extends null nil explict as any enum private number module yield

syntax match GuihuaBufferPath '\.\(\/\a\+\)*\.*\a*'

hi default link GuihuaBufferNumber Number
hi default link GuihuaBufferColon  SpecialChar
hi default link GuihuaBufferPath   Title
hi default link GuihuaBufferKeyword Keyword
hi default link GuihuaBufferString String
hi default link GuihuaBufferString2 String
hi default link GuihuaBufferComment Comment
