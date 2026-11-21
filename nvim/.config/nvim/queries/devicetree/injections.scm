; extends
; #define FOO (BAR + 1) 의 값 부분을 C 로 칠한다(C 쿼리가 하는 방식과 같다).
((preproc_arg) @injection.content
  (#set! injection.language "c"))
