// The runner for exercise 0: no window, only the report. Run with: first.jai - run vulkan/exercise-0

#import "Basic";

main :: () {
    inv, ok := collect_inventory();
    if !ok  exit(1);
    print_inventory(inv);
}
