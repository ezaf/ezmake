/** @file       ezhello.h
 *  @brief      A simple demonstration of how to write, document and include
 *              header files in EzMake.
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

#ifndef EZHELLO_H
#define EZHELLO_H

#ifdef __cplusplus
extern "C"
{
#endif



/**
 *  @brief      Say hello to whoever you want!
 *  @param      subject    String indicating to whom we are saying hello to.
 *  @return     `void`, what did you expect?
 *  @details    Concatenates `"Hello "`, the `subject` parameter, and `"!\n"`.
 */
void ezhello_printHelloTo(const char *subject);



#ifdef __cplusplus
}
#endif

#endif /* EZHELLO_H */
