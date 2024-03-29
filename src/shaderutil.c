/**
 * Some basic utility for working with OpenGL shader programs.
 */

#include "shaderutil.h"
#include <stdlib.h>
#include "common.h"
#include <stdio.h>
#include <assert.h>

static char* malloc_file_source(const char* fpath) {
    FILE* f;
    if ((f = fopen(fpath, "r")) == NULL) {
        fprintf(stderr, "Unable to open file (%s): %s\n", fpath, ERROR());
        exit(1);
    }
    fseek(f, 0, SEEK_END);
    size_t size = ftell(f);
    rewind(f);

    char* s = malloc(size + 1);
    assert(s);

    size_t len = fread(s, 1, size, f);
    fclose(f);

    if (len == 0) {
        fprintf(stderr, "Unable to read file (%s): %s\n", fpath, ERROR());
        exit(1);
    }
    s[len] = '\0';

    return s;
}

static const char* shaderTypeCStr(GLenum shaderType) {
    switch (shaderType) {
    case GL_VERTEX_SHADER: return "Vertex";
    case GL_FRAGMENT_SHADER: return "Fragment";
    default: return "??";
    }
}


static GLuint load_shader(GLenum shaderType, const char* source, const char *from) {
    fflush(stdout);
    GLuint shader = glCreateShader(shaderType);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    GLint compiled = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) {
        GLchar error_msg[GL_INFO_LOG_LENGTH];
        glGetShaderInfoLog(shader, GL_INFO_LOG_LENGTH, NULL, error_msg);
        fprintf(stderr, "Error compiling shader (%s Shader) (in %s) %s\n", shaderTypeCStr(shaderType), from, error_msg);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

static void build_shader(GLuint program, const char *source, GLenum type, const char *id) {
    GLuint shader = load_shader(type, source, id);
    if (!shader) exit(1);
    glAttachShader(program, shader);
}

static void build_shader_from_file(GLuint program, const char *file_name, GLenum type) {
    char *source = malloc_file_source(file_name);
    build_shader(program, source, type, file_name);
    free(source);
}

static const char* get_gl_error_message(GLenum err) {
    switch (err) {
        case GL_INVALID_ENUM: return "(GL_INVALID_ENUM) invalid argument for enumerated parameter";
        case GL_INVALID_VALUE: return "(GL_INVALID_VALUE) numeric argument out of range";
        case GL_INVALID_OPERATION: return "(GL_INVALID_OPERATION) operation is invalid";
        case GL_INVALID_FRAMEBUFFER_OPERATION: return "(GL_INVALID_FRAMEBUFFER_OPERATION) framebuffer object is not complete";
        case GL_OUT_OF_MEMORY: return "(GL_OUT_OF_MEMORY) ";
        default: return "no error recorded";
    }
}

#define VERT_POS_ATTRIB_INDEX 0

void shader_init(Shader *sh) {
    GLuint vbo; /* Don't need to hold on to this VBO name, it's in the VAO */
    // Gen
    glGenBuffers(1, &vbo);
    glGenVertexArrays(1, &sh->vao);

    // Bind
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBindVertexArray(sh->vao);

    glBufferData(GL_ARRAY_BUFFER, sizeof(QUAD), QUAD, GL_STATIC_DRAW);
    glVertexAttribPointer(VERT_POS_ATTRIB_INDEX, 2, GL_FLOAT, GL_FALSE, 0, (void*)0);
    glEnableVertexAttribArray(VERT_POS_ATTRIB_INDEX);

    // Cleanup
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    sh->program = glCreateProgram();
}

static void link_shader_program(Shader *sh) {
    glLinkProgram(sh->program);

    GLint linked = 0;
    glGetProgramiv(sh->program, GL_LINK_STATUS, &linked);
    if (!linked) {
        GLchar error_msg[GL_INFO_LOG_LENGTH];
        glGetProgramInfoLog(sh->program, GL_INFO_LOG_LENGTH, NULL, error_msg);
        fprintf(stderr, "Error linking program: %s\n", error_msg);
        glDeleteProgram(sh->program);
        exit(1);
    }
}

void check_gl_error(const char *file, const int line) {
    GLenum err = glGetError();
    if (err) {
        fprintf(stderr, "%s:%d: %s\n", file, line, get_gl_error_message(err));
        exit(1);
    }
}

void shader_program_from_files(Shader *sh, const char *vert_filename, const char *frag_filename) {
    shader_init(sh);
    build_shader_from_file(sh->program, vert_filename, GL_VERTEX_SHADER); 
    build_shader_from_file(sh->program, frag_filename, GL_FRAGMENT_SHADER); 
    link_shader_program(sh);
}

void shader_program_from_source(Shader *shader, const char *id, const char *vertex_source, const char *fragment_source)
{
    shader_init(shader);
    build_shader(shader->program, fragment_source, GL_FRAGMENT_SHADER, id);
    build_shader(shader->program, vertex_source, GL_VERTEX_SHADER, id);
    link_shader_program(shader);
}

void use_shader_program(Shader *shader)
{
    glUseProgram(shader->program);
    glBindVertexArray(shader->vao);
}

void run_shader_program(Shader *shader)
{
    use_shader_program(shader);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glBindVertexArray(0);
    glUseProgram(0);
}

