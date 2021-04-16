// source: https://raw.githubusercontent.com/jhawthorn/fzy/master/src/match.h
#ifndef MATCH_H
#define MATCH_H MATCH_H

#include <math.h>
#include <stdint.h>

typedef double score_t;
#define SCORE_MAX INFINITY
#define SCORE_MIN -INFINITY

#define MATCH_MAX_LEN 1024

int has_match(const char *needle, const char *haystack, int is_case_sensitive);
score_t match_positions(const char *needle, const char *haystack, uint32_t *positions, int is_case_sensitive);
score_t match(const char *needle, const char *haystack, int is_case_sensitive);
void match_many(const char *needle, const char **haystacks, uint32_t length, score_t *scores, int is_case_sensitive);
void match_positions_many(const char *needle, const char **haystacks, uint32_t length, score_t *scores, uint32_t *positions, int is_case_sensitive);

#endif
