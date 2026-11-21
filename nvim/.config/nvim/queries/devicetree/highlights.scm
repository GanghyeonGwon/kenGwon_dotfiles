; extends
; nvim-treesitter 의 devicetree 하이라이트 규칙에 덧붙인다(위 "; extends" 줄이 있어야 덮어쓰지 않고 더한다).
; 기본 규칙은 매크로와 참조 이름을 모두 @variable 로 칠해서 속성 이름과 같은 색이 된다.
; 색은 lua/plugins/colorscheme.lua 의 *.devicetree 항목에서 정한다.
; 순서가 중요하다: 같은 글자에 규칙이 여러 개 걸리면 뒤에 있는 규칙이 이긴다.

; 1) 대문자 식별자(GPIO_ACTIVE_HIGH, IRQ_TYPE_LEVEL_HIGH, #define 한 이름) → 매크로
((identifier) @constant.macro
  (#lua-match? @constant.macro "^[A-Z][A-Z0-9_]*$"))

; 2) 단, 대문자라도 구조상 역할이 분명한 것은 원래 색으로 되돌린다
;    ACODEC0: acodec0@18 { ... }  /  LDO7 { ... }  /  대문자 속성 이름
;    (label 도 node 의 identifier 자식이라 @module 에 걸리므로 label 을 뒤에 둔다)
(node
  (identifier) @module)
(property
  (identifier) @property)
(node
  label: (identifier) @label)

; 3) 참조 &gpio0, &ACODEC0 → & 와 이름을 라벨 정의와 같은 색으로
(reference
  (identifier) @label)

; 4) 전처리문: C(.h) 와 같은 그룹으로 칠한다 → colorscheme.lua 의 회색 지시어 색이 그대로 적용된다
;    기본 규칙은 #if 계열을 칠하지 않고, #define 줄은 통째로 @constant.macro(보라) 한 덩어리다.
[
  "#if"
  "#ifdef"
  "#ifndef"
  "#elif"
  "#else"
  "#endif"
  "#undef"
] @keyword.directive
"#define" @keyword.directive.define
"#include" @keyword.import
(preproc_defined) @function.macro
(preproc_def
  name: (identifier) @constant.macro)
(preproc_function_def
  name: (identifier) @function.macro)
(preproc_params
  (identifier) @variable.parameter)
; #define 의 값 부분은 injections.scm 에서 C 로 다시 칠한다
