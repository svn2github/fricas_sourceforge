/*
Copyright (c) 1991-2002, The Numerical ALgorithms Group Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    - Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

    - Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in
      the documentation and/or other materials provided with the
      distribution.

    - Neither the name of The Numerical ALgorithms Group Ltd. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include "axiom-c-macros.h"
#include <sys/types.h>
#include <sys/stat.h>

#include "cfuns-c.H1"

/* Most versions of Windows don't have the POSIX functions getuid(),
   geteuid(), getgid(), and getegid().  The following definitions are
   approximations, to patch for the deficiencies of Windows
   POSIX interface.  */

#if !HAVE_DECL_GETUID
#  define getuid() 0
#endif

#if !HAVE_DECL_GETGID
#  define getgid() 0
#endif

#if !HAVE_DECL_GETEUID
#  define geteuid() getuid()
#endif

#if !HAVE_DECL_GETEGID
#  define getegid() getgid()
#endif

int
addtopath(char *dir)
{
    char *path, *newpath;

    path = getenv("PATH");
    if (path == NULL)
        return -1;

    newpath = (char *) malloc(1 + strlen(path) + strlen(dir) + strlen("PATH=:"));
    if (newpath == NULL)
        return -1;

    sprintf(newpath, "PATH=%s;%s", path, dir); /* MSYS/MinGW ??? */

    return putenv(newpath);
}

/*
 * Test whether the path is the name of a directory.  Returns 1 if so, 0 if
 * not, -1 if it doesn't exist.
 */


int
directoryp(char *path)
{
    struct stat buf;
    int code;

    code = stat(path, &buf);
    if (code == -1) {
        return (-1);
    }
    else {
        return ((buf.st_mode & S_IFDIR) != 0);
    }
}


/* Make a directory returning 0 for success and -1 for failure */

int
makedir(char *path)
{
#ifdef S_IRWXO
   return ( mkdir (path,(S_IRWXU | S_IRWXO | S_IRWXG)) );
#else
   return ( mkdir (path) );
#endif
}

int
make_path_from_file(char *s, char *t)
{
    char *pos = NULL;
    char *c;

    /** simply copies the path name from t into s **/
    for (c = t + strlen(t); c != t; c--)
        if ( ( *c == '/' ) || ( *c == '\\' ) ) {
            pos = c;
            break;
        }
    /** Check to see if the path was actually present **/
    if (c == t) {               /** No Path, so return the pwd **/
        return (-1);
    }
    /** now just do the copying **/
    strncpy(s, t, pos - t);
    return 1;
}

/* The functions writeablep() and readablep() determine write and
   read access of a file designated by its name.  The function
   axiom_has_write_access is a sub-routine of writeablep.

   The access is determined based on the POSIX semantics; see
   "Advanced Programming in the UNIX Environement", section 4.5.

   1. If the effective user ID of the process is 0 (the superuser),
      access is allowed.  This gives the superuser free rein throughout
      the entire file system.

   2. If the effective user ID of the process equals the owner ID of
      the file (i.e., the process owns the file), access is allowed
      if the appropriate user access permission bit is set. [...]

   3. If the effective group ID of the process or one of the
      supplementary group IDs of the process equals the group ID
      of the file, access is allowed if the appropriate
      group access permission bit is set.  Otherwise, permission
      is denied.

   4. If the appropriate other access permission bit is set, access is
      allowed.  Otherwise, permission is defined.   */


/* Return 1 if the process has write access of file as explained above.
   Otherwise, return 0.  */

static inline int
axiom_has_write_access(const struct stat* file_info)
{
   int effetive_uid = geteuid();

   if (effetive_uid == 0)
      return 1;

   if (effetive_uid == file_info->st_uid)
      return file_info->st_mode & S_IWUSR;

#ifdef S_IWGRP
   if (getegid() == file_info->st_gid)
      return file_info->st_mode & S_IWGRP;
#endif

#ifdef S_IWOTH
   return file_info->st_mode & S_IWOTH;
#else
   return 0;
#endif
}


/* Return
     -1 if the file designated by PATH is inexistent.
      0 if the file exists but wirte access is denied.
      1 if the file exists and process has write access.
      2 if the file does not exists but process has write
        has write access to the dirname of path.  */

int
writeablep(char *path)
{
    struct stat buf;
    char newpath[100];
    int code;

    code = stat(path, &buf);
    if (code == -1) {
        /** The file does not exist, so check to see
                 if the directory is writable                  *****/
        if (make_path_from_file(newpath, path) == -1 ||
            stat(newpath, &buf) == -1) {
            return (-1);
        }
    }
    else if (geteuid() == buf.st_uid) {
        return ((buf.st_mode & S_IWUSR) != 0);
#ifdef S_IWGRP
    }
    else if (getegid() == buf.st_gid) {
        return ((buf.st_mode & S_IWGRP) != 0);
#endif
#ifdef S_IWOTH
    }
    else {
        return ((buf.st_mode & S_IWOTH) != 0);
#endif
    };
    return ( 1 ); /* MSYS/MinGW */
}


int
readablep(char *path)
{
    struct stat buf;
    int code;

    code = stat(path, &buf);
    if (code == -1) {
        return (-1);
    }
    else if (geteuid() == buf.st_uid) {
        return ((buf.st_mode & S_IREAD) != 0);
#ifdef S_IRGRP
    }
    else if (getegid() == buf.st_gid) {
        return ((buf.st_mode & S_IRGRP) != 0);
#endif
#ifdef S_IROTH
    }
    else {
     return ((buf.st_mode & S_IROTH) != 0);
#endif
    };
    return ( 1 ); /* MSYS/MinGW */
}


long
findString(char *file, char *string)
{
    int nstring, charpos;
    FILE *fn;
    char buffer[1024];

    if ((fn = fopen(file, "r")) == NULL)
        return -1;

    for (charpos = 0, nstring = strlen(string);
         fgets(buffer, sizeof buffer, fn) != NULL;
         charpos += strlen(buffer)
        )
        if (!strncmp(buffer, string, nstring))
            return charpos;
    return -1;

}

