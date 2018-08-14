#include "ezboth/ezboth.h"
#include "ezhello/ezhello.h"
#include "ezgoodbye/ezgoodbye.h"



void ezboth_say_to(char const *name)
{
    ezhello_say_to(name);
    ezhello_say_to(name);
    ezhello_say_to(name);
    ezgoodbye_say_to(name);
}
