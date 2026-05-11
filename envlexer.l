%{
#include <stdio.h>
#include <string.h>

int line_num    = 1;
int token_count = 0;
int risk_count  = 0;
int invalid_count = 0;

void print_token(const char *type, const char *value, const char *risk);
void print_sep();
%}

%x VALUE_STATE

KEY        [A-Z_][A-Z0-9_]*
WS         [ \t]+
NEWLINE    \n
COMMENT    #[^\n]*
EXPORT_KW  export
ESC_SEQ    \\[ntrfb\\"']

%%

<INITIAL>{WS}              { /* skip leading whitespace */ }

<INITIAL>{COMMENT}         { print_token("COMMENT      ", yytext, NULL); }

<INITIAL>{EXPORT_KW}/{WS}  { print_token("EXPORT_KW    ", yytext, NULL); }

<INITIAL>{KEY}             { print_token("KEY          ", yytext, NULL); }

<INITIAL>"="               {
                               print_token("EQUALS       ", yytext, NULL);
                               BEGIN(VALUE_STATE);
                           }

<INITIAL>{NEWLINE}         {
                               printf("  [line %d] NEWLINE\n", line_num);
                               line_num++;
                           }
    
<INITIAL>[a-z_][a-zA-Z0-9_]* {
                                print_token("INVALID_KEY  ", yytext, "RISK: lowercase key, not portable");
                                invalid_count++;
                            }
    
<INITIAL>[A-Z_][A-Z0-9_]*[a-z][^\n]* {
                                print_token("INVALID_KEY  ", yytext, "RISK: mixed-case key, not portable");
                                invalid_count++;
                            }

<INITIAL>.                 {
                               print_token("INVALID      ", yytext,
                                   "RISK: unparseable token");
                               invalid_count++;
                           }


<VALUE_STATE>{WS}          { /* skip whitespace after = */ }

<VALUE_STATE>'[^'\n]*'     {
                               print_token("SINGLE_QUOTED", yytext, NULL);
                               BEGIN(INITIAL);
                           }

<VALUE_STATE>'[^'\n]*\n    {
                               print_token("INVALID      ", yytext,
                                   "RISK: unclosed single-quoted string");
                               invalid_count++;
                               line_num++;
                               BEGIN(INITIAL);
                           }

<VALUE_STATE>\"({ESC_SEQ}|[^"\\\n])*\" {
                               print_token("DOUBLE_QUOTED", yytext, NULL);
                               BEGIN(INITIAL);
                           }

<VALUE_STATE>\"({ESC_SEQ}|[^"\\])*\" {
                               int i;
                               print_token("MULTILINE_VAL", yytext, NULL);
                               for (i = 0; yytext[i]; i++)
                                   if (yytext[i] == '\n') line_num++;
                               BEGIN(INITIAL);
                           }

<VALUE_STATE>\"[^"\n]*\n   {
                               print_token("INVALID      ", yytext,
                                   "RISK: unclosed double-quoted string");
                               invalid_count++;
                               line_num++;
                               BEGIN(INITIAL);
                           }

<VALUE_STATE>\$\{[A-Z_][A-Z0-9_]*\} {
                               print_token("VAR_EXPANSION", yytext,
                                   "RISK: platform-dependent -- expanded by Docker/Bash, literal in Node/Python");
                               risk_count++;
                           }

<VALUE_STATE>\$[A-Z_][A-Z0-9_]* {
                               print_token("VAR_SHORT    ", yytext,
                                   "RISK: platform-dependent -- boundary ambiguous in shell");
                               risk_count++;
                           }

<VALUE_STATE>\$            {
                               print_token("INVALID      ", yytext,
                                   "RISK: bare $ -- undefined behavior across platforms");
                               invalid_count++;
                           }

<VALUE_STATE>[^\n#"'\$\t ]+ {
                               print_token("UNQUOTED_VAL ", yytext, NULL);
                           }

<VALUE_STATE>[ \t]*{COMMENT} {
                               const char *c = yytext;
                               while (*c == ' ' || *c == '\t') c++;
                               print_token("INLINE_CMT   ", c, NULL);
                               BEGIN(INITIAL);
                           }

<VALUE_STATE>{NEWLINE}     {
                               printf("  [line %d] NEWLINE\n", line_num);
                               line_num++;
                               BEGIN(INITIAL);
                           }

<VALUE_STATE>.             {
                               print_token("INVALID      ", yytext,
                                   "RISK: unparseable token in value");
                               invalid_count++;
                           }

%%

void print_token(const char *type, const char *value, const char *risk) {
    token_count++;
    if (risk) {
        printf("  [line %2d]  %-14s | %-30s | !! %s\n",
               line_num, type, value, risk);
    } else {
        printf("  [line %2d]  %-14s | %s\n",
               line_num, type, value);
    }
}

void print_sep() {
    int i;
    printf("  ");
    for (i = 0; i < 88; i++) printf("-");
    printf("\n");
}

int yywrap() { return 1; }

int main(int argc, char *argv[]) {
    if (argc > 1) {
        FILE *f = fopen(argv[1], "r");
        if (!f) {
            fprintf(stderr, "Error: cannot open file '%s'\n", argv[1]);
            return 1;
        }
        yyin = f;
    }

    printf("\n");
    printf("  +----------------------------------------------------------+\n");
    printf("  |   .env Formal Lexical Analyzer  CT-367                |\n");
    printf("  +----------------------------------------------------------+\n");
    printf("\n");
    print_sep();
    printf("  [line ##]  TOKEN TYPE      | VALUE                          | RISK\n");
    print_sep();

    yylex();

    print_sep();
    printf("\n");
    printf("  SUMMARY\n");
    printf("  -------\n");
    printf("  Total lines    : %d\n", line_num - 1);
    printf("  Total tokens   : %d\n", token_count);
    printf("  Risk sites     : %d  (lines where platforms disagree)\n", risk_count);
    printf("  Invalid tokens : %d  (lines no platform can parse cleanly)\n", invalid_count);
    printf("\n");

    if (risk_count == 0 && invalid_count == 0) {
        printf("  CLEAN: This .env file is safe across Node.js, Python, Docker, and Bash.\n");
    } else {
        printf("  WARNING: Review flagged tokens before deploying to multi-platform environment.\n");
    }
    printf("\n");

    return 0;
}
