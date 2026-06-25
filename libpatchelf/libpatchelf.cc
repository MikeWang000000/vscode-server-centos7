#define main(ARGC, ARGV) patchelf_main(ARGC, ARGV)
#define _FILE_OFFSET_BITS 64
#include "libpatchelf.h"
#include "patchelf/src/patchelf.cc"

int patchelf_get_interpreter(const char *filename, char *interpreter,
                             size_t n, int print_err)
{
    try {
        auto fileContents = readFile(filename);
        std::string interp;

        if (getElfType(fileContents).is32Bit) {
            ElfFile<Elf32_Ehdr, Elf32_Phdr, Elf32_Shdr, Elf32_Nhdr, Elf32_Addr, Elf32_Off,
                    Elf32_Dyn, Elf32_Sym, Elf32_Versym, Elf32_Verdef,
                    Elf32_Verdaux, Elf32_Verneed, Elf32_Vernaux, Elf32_Rel,
                    Elf32_Rela, 32> elfFile(fileContents);
            interp = elfFile.getInterpreter();
        } else {
            ElfFile<Elf64_Ehdr, Elf64_Phdr, Elf64_Shdr, Elf64_Nhdr, Elf64_Addr, Elf64_Off,
                    Elf64_Dyn, Elf64_Sym, Elf64_Versym, Elf64_Verdef,
                    Elf64_Verdaux, Elf64_Verneed, Elf64_Vernaux, Elf64_Rel,
                    Elf64_Rela, 64> elfFile(fileContents);
            interp = elfFile.getInterpreter();
        }
        if (interp.size() >= n)
            error("interpreter string too long");
        strncpy(interpreter, interp.c_str(), n);
    } catch (std::exception & e) {
        if (print_err) {
            fprintf(stderr, "patchelf: %s\n", e.what());
        }
        return -1;
    }
    return 0;
}

int patchelf_set_interpreter(const char *filename, const char *filename_new,
                             const char *interpreter, int print_err)
{
    try {
        auto fileContents = readFile(filename);
        std::string newInterpreter(interpreter);

        if (getElfType(fileContents).is32Bit) {
            ElfFile<Elf32_Ehdr, Elf32_Phdr, Elf32_Shdr, Elf32_Nhdr, Elf32_Addr, Elf32_Off,
                    Elf32_Dyn, Elf32_Sym, Elf32_Versym, Elf32_Verdef,
                    Elf32_Verdaux, Elf32_Verneed, Elf32_Vernaux, Elf32_Rel,
                    Elf32_Rela, 32> elfFile(fileContents);
            elfFile.setInterpreter(newInterpreter);
            writeFile(filename_new, elfFile.fileContents);
        } else {
            ElfFile<Elf64_Ehdr, Elf64_Phdr, Elf64_Shdr, Elf64_Nhdr, Elf64_Addr, Elf64_Off,
                    Elf64_Dyn, Elf64_Sym, Elf64_Versym, Elf64_Verdef,
                    Elf64_Verdaux, Elf64_Verneed, Elf64_Vernaux, Elf64_Rel,
                    Elf64_Rela, 64> elfFile(fileContents);
            elfFile.setInterpreter(newInterpreter);
            writeFile(filename_new, elfFile.fileContents);
        }
    } catch (std::exception & e) {
        if (print_err) {
            fprintf(stderr, "patchelf: %s\n", e.what());
        }
        return -1;
    }
    return 0;
}
