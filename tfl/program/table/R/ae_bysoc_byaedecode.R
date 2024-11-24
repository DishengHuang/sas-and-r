rm(list = ls())

library(tidyverse)
library(officer)
library(flextable)
library(haven)


# read the input dataset --------------------------------------------------

## adsl
adsl <- read_xpt("../../../data/adsl.xpt")

## add total
adsl_tot <- adsl %>% mutate(ARM = "Total")
adsl <- bind_rows(adsl, adsl_tot)
adsl <- adsl %>% rename(TRTA = ARM)

## adae
adae <- read_xpt("../../../data/adae.xpt")

## add total
adae_tot <- adae %>% mutate(TRTA = "Total")
adae <- bind_rows(adae, adae_tot)


# AE by SOC ---------------------------------------------------------------

ae_soc <- adae %>% filter(SAFFL == "Y") %>%
  group_by(TRTA, AESOC) %>%
  summarise(n_soc = n_distinct(USUBJID)) %>%
  mutate(ord = 1)

# AE by SOC by PT ----------------------------------------------------------

ae_soc_pt <- adae %>% filter(SAFFL == "Y") %>%
  group_by(TRTA, AESOC, AEDECOD) %>%
  summarise(n_soc_pt = n_distinct(USUBJID)) %>%
  mutate(ord = 2)

# Combine two datasets ----------------------------------------------------

combine_df <- dplyr::bind_rows(ae_soc, 
                               ae_soc_pt)

## get all the nums
combine_df <- combine_df %>% 
  mutate(num = case_when(!is.na(n_soc) ~ n_soc, 
                         !is.na(n_soc_pt) ~ n_soc_pt, 
                         T ~ NA))


# Compute the percentage --------------------------------------------------

adsl_tr <- adsl %>% select(USUBJID, TRTA)

adsl_tr_sum <- adsl_tr %>% 
  group_by(TRTA) %>%
  summarise(n_pt = n_distinct(USUBJID))

combine_df <- combine_df %>% 
  left_join(adsl_tr_sum) %>%
  mutate(
    n_pct = paste0(num, " (", round(num/n_pt, 3) * 100, ")")
  )


# Get the summary table ---------------------------------------------------
all_summary <- combine_df %>%
  arrange(TRTA, AESOC, n_soc, n_soc_pt)

## new term
all_summary <- all_summary %>% 
  mutate(new_term = if_else(
    !is.na(n_soc), AESOC, paste0("  ", AEDECOD)
  )) %>% 
  select(TRTA, new_term, n_pct) %>%
  pivot_wider(
    names_from = TRTA,
    values_from = n_pct
  )

all_summary[is.na(all_summary)] <- "0"

all_summary <- all_summary %>% select(new_term, Placebo, 
                                      `Xanomeline Low Dose`, 
                                      `Xanomeline High Dose`,
                                      Total)


# format the table header -------------------------------------------------
names(all_summary) <- c("System Organ Class\n  Preferred Term", 
                        paste0("Placebo\n(N = ", adsl_tr_sum$n_pt[adsl_tr_sum$TRTA == "Placebo"], "\nn (%)"), 
                        paste0("Low Dose\n(N = ", adsl_tr_sum$n_pt[adsl_tr_sum$TRTA == "Xanomeline Low Dose"], "\nn (%)"),
                        paste0("High Dose\n(N = ", adsl_tr_sum$n_pt[adsl_tr_sum$TRTA == "Xanomeline High Dose"], "\nn (%)"),
                        paste0("Total\n(N = ", adsl_tr_sum$n_pt[adsl_tr_sum$TRTA == "Total"], "\nn (%)")
                        )



# export to rtf -----------------------------------------------------------

ft <- flextable(all_summary)

ft <- add_header_lines(ft, values = c("Summary of TEAEs by SOC by PT\nSafety Analysis Set"))

ft <- theme_vanilla(ft)
ft <- align(ft, align = "center", part = "all")

ft <- font(ft, fontname = "Courier New", part = "all")

ft <- align(ft, align = "left", j = 1, part = "body")

ft <- fontsize(ft, size = 8, part = "all")
ft <- autofit(ft)
ft <- padding(ft, padding = 0.2, part = "all")

ft <- border_remove(ft)

ft <- hline(ft, part = "header", border = fp_border(color = "black", width = 1))

ft <- hline_top(ft, part = "footer", border = fp_border(color = "black", width = 1))

doc <- read_docx()

doc <- body_add_flextable(doc, value = ft)

print(doc, target = paste0("../../../output/table/AE_BYSOC_BYAEDECOD_R.docx"))



