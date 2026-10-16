// A twelve-line Jai file the checker's data-src rule resolves against.
#import "Basic";

main :: () {
    x := 1;
    y := 2;
    z := x + y;
    print("%\n", z);
    assert(z == 3);
    assert(x < y);
    assert(y < z);
}
