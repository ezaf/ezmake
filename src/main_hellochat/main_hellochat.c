/** @file       main_hellochat.c
 *  @brief      Apps are added just like unit tests. Nonetheless, here is an
 *              example of the former.
 *  @details    The newest trending social media app! Say hello to whoever you
 *              want, right on the command line, powered by the lean-and-mean
 *              EzHello API!
 *
 *  <!-------------------------------------------------------------------------
 *  Copyright (c) 2018 Kirk Lange <github.com/kirklange>
 *  
 *  This software is provided 'as-is', without any express or implied
 *  warranty.  In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  1. The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  2. Altered source versions must be plainly marked as such, and must not be
 *     misrepresented as being the original software.
 *  3. This notice may not be removed or altered from any source distribution.
 *  -------------------------------------------------------------------------->
 */

#include "EzHello/ezhello.h"

#include <stddef.h>
#include <stdio.h>
#include <string.h>



int main(int argc, char *argv[])
{
    const size_t INPUT_SIZE = 64;
    char subject[INPUT_SIZE];
    char *quit_code = "/q";
    
    fprintf(stdout, "Welcome to HelloChat, the newest trending social media "
            "app!\nType \"%s\" to quit. Hit ENTER to submit your responses.\n",
            quit_code);

    while (1)
    {
        /* Ask the user for input */
        fprintf(stdout, "\nWho would you like to say hello to? ", subject);
        fgets(subject, INPUT_SIZE, stdin);

        /* Delete the last character of the input (i.e. drop the '\n') */
        subject[strlen(subject)-1] = '\0';
        
        /* Exit program if user inputed the quit code */
        if (strcmp(subject, quit_code) == 0)
            break;
        else
            ezhello_printHelloTo(subject);
    }

    fprintf(stdout, "Goodbye!\n");

    return 0;
}

