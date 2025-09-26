#include <libguile.h>

int main(int argc, char** argv) {
    SCM hi = scm_c_public_variable("taggy", "hi");
    scm_eval(hi, scm_interaction_environment());
    return 0;
}
