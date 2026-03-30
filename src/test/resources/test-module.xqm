xquery version "4.0";

(:~
 : A test module for xqdoc generation.
 : @author Test Author
 : @version 1.0
 :)
module namespace test = "http://example.com/test";

declare namespace math = "http://www.w3.org/2005/xpath-functions/math";

import module namespace functx = "http://www.functx.com";

(:~ A string constant. :)
declare variable $test:VERSION as xs:string := "1.0.0";

(:~
 : Add two numbers.
 : @param $a first number
 : @param $b second number
 : @return the sum
 :)
declare function test:add($a as xs:integer, $b as xs:integer) as xs:integer {
  $a + $b
};

(:~ Identity function with no type annotations. :)
declare function test:identity($x) {
  $x
};

declare %private function test:helper() as empty-sequence() {
  ()
};
