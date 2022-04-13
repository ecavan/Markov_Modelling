##################
#### PACKAGES ####
##################
load.libraries = c("data.table", "tidyverse", "stringr", 'mgcv', 'MLmetrics', 'ModelMetrics', 'xgboost', 'Matrix', 'ggthemes', 'akima', 'colorspace', 'marmap', 'ggforce', "ggiraph", "formattable", "kableExtra", "ggpubr")

install.lib = load.libraries[!load.libraries %in% installed.packages()]
for (libs in install.lib) {install.packages(libs, dependencies = TRUE)}
sapply(load.libraries, require, character = TRUE)


##############
#### DATA ####
##############
dat = rbind(read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week1.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week2.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week3.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week4.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week5.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week6.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week7.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week8.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week9.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week10.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week11.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week12.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week13.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week14.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week15.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week16.csv"),
            read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/week17.csv"))
plays = read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/Data/BDB Data/plays.csv")


##############################
#### DATA STANDARDIZATION ####
##############################
fulldata = dat %>%
  inner_join(plays) %>%
  filter(!is.na(preSnapHomeScore)) %>%
  mutate(x_std = ifelse(playDirection == "left", 120-x, x), y_std = ifelse(playDirection == "left", 160/3 - y, y)) %>%
  mutate(dir_std = ifelse(playDirection == "left" & dir < 180, dir+180, ifelse(playDirection == "left" & dir > 180,dir-180, dir))) %>%
  mutate(start_yard_line = ifelse(is.na(yardlineSide), yardlineNumber, 
                                  ifelse(possessionTeam == yardlineSide, yardlineNumber, 100 - yardlineNumber)))


#############################
#### BINNING ALL TARGETS ####
#############################
# filter for targets (complete or incomplete)
targets = fulldata %>%
  filter(event %in% c("pass_outcome_caught", "pass_outcome_incomplete", "pass_outcome_touchdown", "pass_outcome_interception"))%>%
  mutate(first_initial = substr(str_split_fixed(displayName, "[ ]",2)[,1],1,1),
         last_name = str_split_fixed(displayName, "[ ]",2)[,2])

# extract receiver name
split = data.frame(receiver = word(str_split(targets$playDescription, " to ", simplify = TRUE)[,2], 1))
names = data.frame(first_int = str_split_fixed(split$receiver, "[.]", 2)[,1],
                   receiver_ln = str_split_fixed(split$receiver, "[.]", 2)[,2])

# filter for receiving player only
full_targets = cbind(targets, names) %>%
  filter(first_initial == first_int & last_name == receiver_ln) %>%
  mutate(pass_yards = (x_std-10) - start_yard_line)

# bin into short, mid, long, deep
bin_data = full_targets %>%
  mutate(caught = ifelse(event %in% c("pass_outcome_caught", "pass_outcome_touchdown"), "complete", "incomplete")) %>%
  select(gameId, playId, displayName, position, route, quarter, down, yardsToGo, possessionTeam, epa, caught, event,start_yard_line, x_std, y_std, pass_yards) %>%
  mutate(pass_length =  ifelse(pass_yards < 0, "screen",
                               ifelse(pass_yards >=0 & pass_yards <= 10, "short",
                                      ifelse(pass_yards > 10 & pass_yards <= 20, "mid","long"))))%>%
  mutate(field_loc = ifelse(pass_length %in% c("short", "mid", "long") & y_std <= 17.77, "right", 
                            ifelse(pass_length %in% c("short", "mid", "long") & y_std >= 35.54, "left",
                                   ifelse(pass_length %in% c("screen") & y_std < 26.65, "right",
                                          ifelse(pass_length %in% c("screen") & y_std >= 26.65, "left", "middle"))))) 

# bin into pass_length by player
target_bins = full_targets %>%
  mutate(caught = ifelse(event %in% c("pass_outcome_caught", "pass_outcome_touchdown"), "complete", "incomplete")) %>%
  select(gameId, playId, displayName, position, route, quarter, down, yardsToGo, possessionTeam, epa, caught, start_yard_line, x_std, y_std, pass_yards) %>%
  mutate(pass_length =  ifelse(pass_yards < 0, "screen",
                               ifelse(pass_yards >=0 & pass_yards <= 10, "short",
                                      ifelse(pass_yards > 10 & pass_yards <= 20, "mid","long"))))%>%
  mutate(field_loc = ifelse(pass_length %in% c("short", "mid", "long") & y_std <= 17.77, "right", 
                            ifelse(pass_length %in% c("short", "mid", "long") & y_std >= 35.54, "left",
                                   ifelse(pass_length %in% c("screen") & y_std < 26.65, "right",
                                          ifelse(pass_length %in% c("screen") & y_std >= 26.65, "left", "middle"))))) %>%
  group_by(displayName, pass_length, field_loc, caught) %>%
  summarise(count = n()) %>%
  pivot_wider(names_from = caught, values_from = count) %>%
  pivot_wider(names_from = pass_length, values_from = c(complete, incomplete)) %>%
  pivot_wider(names_from = field_loc, values_from = c(complete_screen, complete_short, complete_mid, complete_long, incomplete_screen, incomplete_short, incomplete_mid, incomplete_long)) %>%
  
  #order columns
  select(Player = displayName, complete_screen_right, complete_screen_left, complete_short_middle, complete_short_right, complete_short_left, complete_mid_middle, complete_mid_right, complete_mid_left, complete_long_middle, complete_long_right, complete_long_left, incomplete_screen_right, incomplete_screen_left, incomplete_short_middle, incomplete_short_right, incomplete_short_left, incomplete_mid_middle, incomplete_mid_right, incomplete_mid_left, incomplete_long_middle, incomplete_long_right, incomplete_long_left) %>%
  
  mutate_all(~coalesce(.,0)) %>%
  mutate(catch_perc_screen_right = complete_screen_right/(complete_screen_right + incomplete_screen_right),
         catch_perc_screen_left = complete_screen_left/(complete_screen_left + incomplete_screen_left),
         catch_perc_short_middle = complete_short_middle/(complete_short_middle + incomplete_short_middle),
         catch_perc_short_right = complete_short_right/(complete_short_right + incomplete_short_right),
         catch_perc_short_left = complete_short_left/(complete_short_left + incomplete_short_left),
         catch_perc_mid_middle = complete_mid_middle/(complete_mid_middle + incomplete_mid_middle),
         catch_perc_mid_right = complete_mid_right/(complete_mid_right + incomplete_mid_right),
         catch_perc_mid_left = complete_mid_left/(complete_mid_left + incomplete_mid_left),
         catch_perc_long_middle = complete_long_middle/(complete_long_middle + incomplete_long_middle),
         catch_perc_long_right = complete_long_right/(complete_long_right + incomplete_long_right),
         catch_perc_long_left = complete_long_left/(complete_long_left + incomplete_long_left)) 


##################################
#### DATA FOR EACH PLAY/DRIVE ####
##################################

# filter for targets (complete or incomplete)
drive_data = fulldata %>%
  filter(event %in% c("pass_outcome_caught", "pass_outcome_incomplete", "pass_outcome_touchdown", "pass_outcome_interception"))%>%
  mutate(first_initial = substr(str_split_fixed(displayName, "[ ]",2)[,1],1,1),
         last_name = str_split_fixed(displayName, "[ ]",2)[,2]) %>%
  mutate(catch_result_td = ifelse(grepl("TOUCHDOWN", playDescription, fixed = TRUE) == TRUE, 1, 0))

# extract receiver name
split = data.frame(receiver = word(str_split(drive_data$playDescription, " to ", simplify = TRUE)[,2], 1))
names = data.frame(first_int = str_split_fixed(split$receiver, "[.]", 2)[,1],
                   receiver_ln = str_split_fixed(split$receiver, "[.]", 2)[,2])

# filter for receiving player only
full_drive = cbind(drive_data, names) %>%
  filter(first_initial == first_int & last_name == receiver_ln) %>%
  mutate(pass_yards = (x_std-10) - start_yard_line)

# identify each drive
drives = plays %>% 
  select(gameId, playId, possessionTeam) %>%
  arrange(gameId, playId) %>%
  group_by(drive = rleid(possessionTeam))

# add drives to play data
plays_data = full_drive %>%
  mutate(caught = ifelse(event %in% c("pass_outcome_caught", "pass_outcome_touchdown"), "complete", "incomplete")) %>%
  mutate(pass_length =  ifelse(pass_yards < 0, "screen",
                               ifelse(pass_yards >=0 & pass_yards <= 10, "short",
                                      ifelse(pass_yards > 10 & pass_yards <= 20, "mid","long"))))%>%
  mutate(field_loc = ifelse(pass_length %in% c("short", "mid", "long") & y_std <= 17.77, "right", 
                            ifelse(pass_length %in% c("short", "mid", "long") & y_std >= 35.54, "left",
                                   ifelse(pass_length %in% c("screen") & y_std < 26.65, "right",
                                          ifelse(pass_length %in% c("screen") & y_std >= 26.65, "left", "middle"))))) %>%
  mutate(score_diff_team = ifelse(team == "away", preSnapVisitorScore - preSnapHomeScore, preSnapHomeScore - preSnapVisitorScore),
         score_diff = preSnapHomeScore - preSnapVisitorScore) %>%
  mutate(YAC = offensePlayResult - pass_yards) %>%
  inner_join(drives) %>%
  select(gameId, playId, drive, possessionTeam, team, caught, catch_result_td, displayName, jerseyNumber, position, route, quarter, down, yardsToGo, score_diff_team, score_diff, epa, x_std, y_std, start_yard_line, offensePlayResult, pass_yards, pass_length, field_loc) %>%
  arrange(drive, playId) %>%
  mutate(last_play_drive = ifelse(lead(drive) == drive, "N", "Y"))


######################
#### MARKOV CHAIN ####
######################

#### DATA PREP ####
mc_data = plays_data %>%
  # play states
  mutate(YTG = ifelse(yardsToGo <=5, "short",
                      ifelse(yardsToGo > 10, "long", "mid")),
         field_position = ifelse(start_yard_line <= 20, "0 to 20",
                                 ifelse(start_yard_line > 20 & start_yard_line <= 40, "21 to 40",
                                        ifelse(start_yard_line > 40 & start_yard_line <= 60, "41 to 60",
                                               ifelse(start_yard_line > 60 & start_yard_line <= 80, "61 to 80", "81 to 100")))),
         DOWN = ifelse(down == 1, "1st",
                       ifelse(down == 2, "2nd",
                              ifelse(down == 3, "3rd", "4th")))) %>%
  unite(play_state, DOWN, YTG, field_position, sep = "-", remove = FALSE) %>%
  
  # absorption states
  group_by(gameId) %>%
  mutate(absorption_state = 
           ifelse(last_play_drive == "Y" & abs(lead(score_diff) - score_diff) == 3, "FG",
                  ifelse(last_play_drive == "Y" & abs(lead(score_diff) - score_diff) >= 6 & catch_result_td == 0, "TD Run", 
                         ifelse(last_play_drive == "Y" & catch_result_td == 1, "TD Pass", 
                                ifelse(last_play_drive == "Y" & abs(lead(score_diff) - score_diff) == 0, "Drive End", NA))))) %>%
  ungroup() %>%
  
  # next state
  mutate(next_state = ifelse(lead(last_play_drive) == "Y", lead(absorption_state), lead(play_state)))

#### MARKOV CHAIN ####
options(scipen = 999)

# Calculated frequency of each zone "state"
transient_state_df = mc_data %>%
  group_by(play_state) %>%
  count() %>%
  ungroup() %>%
  mutate(state_prop = n / sum(n)) %>% 
  arrange(desc(state_prop))

absorption_states = unique(mc_data$absorption_state)[-1]

# Calculate transition probabilities of each state combination
transitions = mc_data %>% 
  group_by(play_state, next_state) %>%
  count() %>%
  ungroup() %>%
  group_by(play_state) %>%
  mutate(total_plays = sum(n)) %>%
  ungroup() %>%
  mutate(transition_prob = n / total_plays) %>%
  
  # Append rows that are just the absorption for ease in making the complete transition matrix:
  bind_rows(data.frame(play_state = absorption_states,
                       next_state = absorption_states,
                       transition_prob = rep(1, length(absorption_states)))) %>% 
  filter(!is.na(next_state)) %>%
  arrange(desc(n))

# Create transition matrix 
transition_matrix = transitions %>%
  select(play_state, next_state, transition_prob) %>%
  arrange(desc(play_state), desc(next_state)) %>% 
  spread(next_state, transition_prob) 

transition_matrix[is.na(transition_matrix)] <- 0


# data fixing
transition_matrix$`4th-long-81 to 100` = 0
transition_matrix$`4th-mid 0 to 20` = 0
transition_matrix$`4th-short-0 to 20` = 0

new_row = data.frame(matrix(c(rep(0, ncol(transition_matrix)),rep(0, ncol(transition_matrix))), ncol = 65, nrow = 2))
colnames(new_row) = colnames(transition_matrix)
transition_matrix = rbind(transition_matrix, new_row)

transition_matrix[63,1] = "4th-short-0 to 20"
transition_matrix[64,1] = "4th-long-81 to 100"


#### Fundamental Matrix Calculation ####

# Find the indices of absorption states:
row_absorption_i = which(transition_matrix$play_state %in% absorption_states)
col_absorption_i = which(colnames(transition_matrix) %in% absorption_states)

# Grab the Q matrix - n x n transition matrix for transient states:
q_matrix = as.matrix(transition_matrix[-row_absorption_i,
                                       -c(1,col_absorption_i)])
# Grab the R matrix - n x r transition matrix to the absorption states:
r_matrix = as.matrix(transition_matrix[-row_absorption_i,
                                       col_absorption_i])

# Calculate the fundamental matrix - (I-Q)**(-1)
fundamental_matrix = solve(diag(nrow = nrow(q_matrix),
                                ncol = nrow(q_matrix)) - q_matrix)


#### RESULTS ####

# Calculate expected number of plays by zone 
expected_n_plays = rowSums(fundamental_matrix)

# Calculate probability of absorption for each zone
prob_absorption = fundamental_matrix %*% r_matrix

# Make transition probabilities into a cleaner data frame
absorption_df = as.data.frame(prob_absorption) %>%
  mutate(play_state = rownames(prob_absorption),
         expected_n_plays = expected_n_plays) %>% 
  as_tibble() 

# mutate next field position
contr_data = mc_data %>%
  mutate(new_field_position = 
           ifelse(start_yard_line + offensePlayResult < 21 ,"0 to 20",
                  ifelse(start_yard_line + offensePlayResult >= 21 & start_yard_line + offensePlayResult < 41 ,"21 to 40",
                         ifelse(start_yard_line + offensePlayResult >= 41 & start_yard_line + offensePlayResult < 60 ,"41 to 60",
                                ifelse(start_yard_line + offensePlayResult >= 61 & start_yard_line + offensePlayResult < 81 ,"61 to 80", "81 to 100")))), 
         new_down = ifelse(offensePlayResult - yardsToGo >= 0, "1st", 
                           ifelse(down == 1 & offensePlayResult - yardsToGo < 0, "2nd",
                                  ifelse(down == 2 & offensePlayResult - yardsToGo < 0, "3rd", "4th"))),
         new_ytg = ifelse(offensePlayResult - yardsToGo >= 0, "mid",
                          ifelse(yardsToGo - offensePlayResult > 10, "long","short"))) %>%
  unite(new_state, new_down, new_ytg, new_field_position, sep = "-", remove = FALSE) %>%
  mutate(new_state = ifelse(down == 4 & offensePlayResult - yardsToGo < 0, NA, new_state))

# Player contributions
contr = contr_data %>%
  filter(caught == "complete") %>%
  inner_join(absorption_df, by = c("new_state" = "play_state")) %>%
  inner_join(absorption_df, by = c("play_state" = "play_state")) %>%
  mutate(new_epa = (3*FG.x + 7*(`TD Pass.x` + `TD Run.x`)) - (3*FG.y + 7*(`TD Pass.y` + `TD Run.y`))) %>%
  group_by(displayName, position) %>%
  summarise(epa_new = sum(new_epa),
            epa = sum(epa), 
            n = n(), 
            epa_new_per_play = epa_new/n,
            epa_per_play = epa/n) %>%
  arrange(desc(epa_new_per_play)) %>%
  filter(n > 25)


##########################
#### ADD CLUSTER DATA ####
##########################
clust = read_csv("~/Documents/SFU Class Files - Grad/Spring 2022/STAT 853/Project/clusters (1).csv") %>%
  arrange(cluster)

clusters = contr %>%
  inner_join(clust, by = c("displayName" = "Player")) %>%
  group_by(cluster) %>%
  summarise(avg_epa = mean(epa_new_per_play), 
            sum_epa = sum(epa_new))


##########################
#### PLOTS AND TABLES ####
##########################

#### CATCH BIN PLOT ####
catch_bin_plot = ggplot(bin_data %>% filter(event %in% c("pass_outcome_caught", "play_outcome_touchdown"))) +
  
  geom_point(aes(x = (53.3 - y_std), y = pass_yards, color = interaction(pass_length, field_loc)), alpha = 0.5) +
  labs(y = "Pass Yards", x = "") +
  
  # add field lines
  geom_segment(aes(x = 0, y = 0, xend = 53.3, yend = 0)) +
  geom_segment(aes(x = 0, y = 10, xend = 53.3, yend = 10)) +
  geom_segment(aes(x = 0, y = 20, xend = 53.3, yend = 20)) +
  geom_segment(aes(x = 0, y = 30, xend = 53.3, yend = 30)) +
  geom_segment(aes(x = 0, y = 40, xend = 53.3, yend = 40)) +
  geom_segment(aes(x = 0, y = 50, xend = 53.3, yend = 50)) +
  
  geom_segment(aes(x = 0, y = -10, xend = 0, yend = 60)) +
  geom_segment(aes(x = 53.3, y = -10, xend = 53.3, yend = 60)) +
  
  
  # add yardline numbers
  annotate(geom = "text", x = 5, y = 10, label = "1 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 20, label = "2 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 30, label = "3 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 40, label = "4 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 50, label = "5 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 10, label = "1 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 20, label = "2 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 30, label = "3 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 40, label = "4 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 50, label = "5 0", angle = 90, size = 5) +
  
  annotate(geom = "text", x = 57, y = 0, label = "LOS", angle = 0, size = 6) +
  
  
  guides(color=guide_legend(title="Field Location")) +
  lims(x = c(0, 60), y = c(-10,60)) +
  theme_few()


#### EXAMPLE PLAY PLOT ####

d = mc_data %>% filter(drive == 2384) 
d2 = mc_data %>% filter(drive == 2384 & caught == "complete")

example_play_plot = ggplot() +
  
  # add field lines
  geom_segment(aes(x = 0, y = 20, xend = 53.3, yend = 20)) +
  geom_segment(aes(x = 0, y = 30, xend = 53.3, yend = 30)) +
  geom_segment(aes(x = 0, y = 40, xend = 53.3, yend = 40)) +
  geom_segment(aes(x = 0, y = 50, xend = 53.3, yend = 50)) +
  geom_segment(aes(x = 0, y = 60, xend = 53.3, yend = 60)) +
  geom_segment(aes(x = 0, y = 70, xend = 53.3, yend = 70)) +
  geom_segment(aes(x = 0, y = 80, xend = 53.3, yend = 80)) +
  geom_segment(aes(x = 0, y = 90, xend = 53.3, yend = 90)) +
  geom_segment(aes(x = 0, y = 100, xend = 53.3, yend = 100), size = 1.5) +
  geom_segment(aes(x = 0, y = 110, xend = 53.3, yend = 110)) +
  
  geom_segment(aes(x = 0, y = 10, xend = 0, yend = 110)) +
  geom_segment(aes(x = 53.3, y = 10, xend = 53.3, yend = 110)) +
  
  
  # add yardline numbers
  annotate(geom = "text", x = 5, y = 20, label = "2 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 30, label = "3 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 40, label = "4 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 50, label = "5 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 60, label = "4 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 70, label = "3 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 80, label = "2 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 90, label = "1 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 20, label = "2 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 30, label = "3 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 40, label = "4 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 50, label = "5 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 60, label = "4 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 70, label = "3 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 80, label = "2 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 90, label = "1 0", angle = 90, size = 5) +
  
  # catch locations
  geom_point(d %>% filter(caught == "complete"), mapping = aes(x = 53.3-y_std, y = x_std-10), shape = 1, size = 3, color = "blue") +
  geom_point(d %>% filter(caught == "incomplete"), mapping = aes(x = 53.3-y_std, y = x_std-10), shape = 4, size = 4, color = "red") +
  
  # catch lines
  geom_segment(aes(x = 53.3/2, y = d$start_yard_line[1], xend = 53.3-d$y_std[1], yend = d$x_std[1]-10), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = d$start_yard_line[2], xend = 53.3-d$y_std[2], yend = d$x_std[2]-10), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = d$start_yard_line[3], xend = 53.3-d$y_std[3], yend = d$x_std[3]-10), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = d$start_yard_line[4], xend = 53.3-d$y_std[4], yend = d$x_std[4]-10), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = d$start_yard_line[5], xend = 53.3-d$y_std[5], yend = d$x_std[5]-10), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = d$start_yard_line[6], xend = 53.3-d$y_std[6], yend = d$x_std[6]-10), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = d$start_yard_line[7], xend = 53.3-d$y_std[7], yend = d$x_std[7]-10), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = d$start_yard_line[8], xend = 53.3-d$y_std[8], yend = d$x_std[8]-10), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = d$start_yard_line[9], xend = 53.3-d$y_std[9], yend = d$x_std[9]-10), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = d$start_yard_line[10], xend = 53.3-d$y_std[10], yend = d$x_std[10]-10), linetype = 2) +
  
  # YAC lines
  geom_segment(aes(x = 53.3-d2$y_std[1], y = d2$x_std[1] - 10, xend = 53.3-d2$y_std[1], yend = d2$start_yard_line[1] + d2$offensePlayResult[1]), linetype = 2) +
  geom_segment(aes(x = 53.3-d2$y_std[2], y = d2$x_std[2] - 10, xend = 53.3-d2$y_std[2], yend = d2$start_yard_line[2] + d2$offensePlayResult[2]), linetype = 2) +
  geom_segment(aes(x = 53.3-d2$y_std[3], y = d2$x_std[3] - 10, xend = 53.3-d2$y_std[3], yend = d2$start_yard_line[3] + d2$offensePlayResult[3]), linetype = 2) +
  geom_segment(aes(x = 53.3-d2$y_std[4], y = d2$x_std[4] - 10, xend = 53.3-d2$y_std[4], yend = d2$start_yard_line[4] + d2$offensePlayResult[4]), linetype = 2) +
  geom_segment(aes(x = 53.3-d2$y_std[5], y = d2$x_std[5] - 10, xend = 53.3-d2$y_std[5], yend = d2$start_yard_line[5] + d2$offensePlayResult[5]), linetype = 2) +
  geom_segment(aes(x = 53.3-d2$y_std[6], y = d2$x_std[6] - 10, xend = 53.3-d2$y_std[6], yend = d2$start_yard_line[6] + d2$offensePlayResult[6]), linetype = 2) +
  geom_segment(aes(x = 53.3-d2$y_std[7], y = d2$x_std[7] - 10, xend = 53.3-d2$y_std[7], yend = d2$start_yard_line[7] + d2$offensePlayResult[7]), linetype = 2) +
  geom_segment(aes(x = 53.3-d2$y_std[8], y = d2$x_std[8] - 10, xend = 53.3-d2$y_std[8], yend = d2$start_yard_line[8] + d2$offensePlayResult[8]), linetype = 2) +
  geom_segment(aes(x = 53.3-d2$y_std[9], y = d2$x_std[9] - 10, xend = 53.3-d2$y_std[9], yend = d2$start_yard_line[9] + d2$offensePlayResult[9]), linetype = 2) +
  
  # play result dot
  geom_point(data = d %>% filter(caught == "complete"), aes(x = 53.3-y_std, y = start_yard_line + offensePlayResult), color = "blue", size = 3, shape = 16) +
  
  theme_few() 


#### PLAYER COMPLETION/INCOMPLETION SCATTER PLOT ####

player_target_plot = ggplot(mc_data %>% filter(displayName == "Alvin Kamara")) + ## replace name with any player
  
  # add field lines
  geom_segment(aes(x = 0, y = 0, xend = 53.3, yend = 0), linetype = 2) +
  geom_segment(aes(x = 0, y = 10, xend = 53.3, yend = 10), linetype = 2) +
  geom_segment(aes(x = 0, y = 20, xend = 53.3, yend = 20), linetype = 2) +
  geom_segment(aes(x = 0, y = 30, xend = 53.3, yend = 30), color = "grey") +
  geom_segment(aes(x = 0, y = 40, xend = 53.3, yend = 40), color = "grey") +
  geom_segment(aes(x = 0, y = 50, xend = 53.3, yend = 50), color = "grey") +
  
  geom_segment(aes(x = 0, y = -10, xend = 0, yend = 60)) +
  geom_segment(aes(x = 53.3, y = -10, xend = 53.3, yend = 60)) +
  
  geom_segment(aes(x = 53.3/3, y = 0, xend = 53.3/3, yend = 60), linetype = 2) +
  geom_segment(aes(x = (53.3/3)*2, y = 0, xend = (53.3/3)*2, yend = 60), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = -10, xend = 53.3/2, yend = 0), linetype = 2) +
  
  # add yardline numbers
  annotate(geom = "text", x = 5, y = 10, label = "1 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 20, label = "2 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 30, label = "3 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 40, label = "4 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 50, label = "5 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 10, label = "1 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 20, label = "2 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 30, label = "3 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 40, label = "4 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 50, label = "5 0", angle = 90, size = 5) +
  
  annotate(geom = "text", x = 57, y = 0, label = "LOS", angle = 0, size = 6) +
  
  # split into catch bins
  
  
  geom_point(aes(x = (53.3 - y_std), y = pass_yards, color = interaction(pass_length, field_loc), shape = caught)) +
  scale_shape_manual(values = c(16,4)) +
  labs(y = "Pass Yards", x = "") +
  guides(color=guide_legend(title="Field Location"), shape =guide_legend(title = "Catch")) +
  lims(x = c(0, 60), y = c(-10,60)) +
  theme_few() +
  theme(axis.text.x=element_blank(), #remove x axis labels
        axis.ticks.x=element_blank(), #remove x axis ticks
        axis.text.y=element_blank(),  #remove y axis labels
        panel.grid = element_blank(),
        axis.title = element_blank())



#### PLAYER PASS DISTRIBUTION MAP ####
# initialize values for plot 
xmin = c(53.3/2, 0, 53.3/3, (53.3/3)*2, 0, 53.3/3, (53.3/3)*2, 0, 53.3/3, (53.3/3)*2, 0)
xmax = c(53.3, 53.3/2, (53.3/3)*2, 53.3, 53.3/3, (53.3/3)*2, 53.3, 53.3/3, (53.3/3)*2, 53.3, 53.3/3)
ymin = c(-10, -10, 0, 0, 0, 10, 10, 10, 20, 20, 20)
ymax = c(0, 0, 10, 10, 10, 20, 20, 20, 60, 60, 60)

c = target_bins %>% filter(Player == "Alvin Kamara") ## replace with any player name

cols = data.frame(colSums(c[,-1])) %>%
  rownames_to_column("loc") %>%
  pivot_wider(names_from = loc, values_from = colSums.c....1..) %>%
  mutate(catch_perc_screen_right = complete_screen_right/(complete_screen_right + incomplete_screen_right),
         catch_perc_screen_left = complete_screen_left/(complete_screen_left + incomplete_screen_left),
         catch_perc_short_middle = complete_short_middle/(complete_short_middle + incomplete_short_middle),
         catch_perc_short_right = complete_short_right/(complete_short_right + incomplete_short_right),
         catch_perc_short_left = complete_short_left/(complete_short_left + incomplete_short_left),
         catch_perc_mid_middle = complete_mid_middle/(complete_mid_middle + incomplete_mid_middle),
         catch_perc_mid_right = complete_mid_right/(complete_mid_right + incomplete_mid_right),
         catch_perc_mid_left = complete_mid_left/(complete_mid_left + incomplete_mid_left),
         catch_perc_long_middle = complete_long_middle/(complete_long_middle + incomplete_long_middle),
         catch_perc_long_right = complete_long_right/(complete_long_right + incomplete_long_right),
         catch_perc_long_left = complete_long_left/(complete_long_left + incomplete_long_left))

c2 = c[c(1,24:34)] %>%
  pivot_longer(!Player, names_to = "location", values_to = "perc")
plot_dat = cbind(c2, xmin, xmax, ymin, ymax)
colnames(plot_dat) = c("Player", "location", "perc", "xmin", "xmax", "ymin", "ymax")

player_catch_dist = ggplot() +
  
  #tiles
  geom_rect(data = plot_dat, aes(xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax, fill = perc)) +
  scale_fill_gradient2(midpoint = 0.75, low = "gray90", mid = "gray70", high = "steelblue3") +
  
  
  # percentages
  annotate(geom = "text", x = (53.3/4)*3, y = -5, label = paste(round(c2$perc[1]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/4, y = -5, label = paste(round(c2$perc[2]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/2, y = 5, label = paste(round(c2$perc[3]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = (53.3/6)*5, y = 5, label = paste(round(c2$perc[4]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/6, y = 5, label = paste(round(c2$perc[5]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/2, y = 15, label = paste(round(c2$perc[6]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = (53.3/6)*5, y = 15, label = paste(round(c2$perc[7]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/6, y = 15, label = paste(round(c2$perc[8]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/2, y = 35, label = paste(round(c2$perc[9]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = (53.3/6)*5, y = 35, label = paste(round(c2$perc[10]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/6, y = 35, label = paste(round(c2$perc[11]*100, 0), "%"), size = 5) +
  
  
  # add field line
  geom_segment(aes(x = 0, y = 0, xend = 53.3, yend = 0), linetype = 2) +
  geom_segment(aes(x = 0, y = 10, xend = 53.3, yend = 10), linetype = 2) +
  geom_segment(aes(x = 0, y = 20, xend = 53.3, yend = 20), linetype = 2) +
  geom_segment(aes(x = 0, y = 30, xend = 53.3, yend = 30), color = "grey") +
  geom_segment(aes(x = 0, y = 40, xend = 53.3, yend = 40), color = "grey") +
  geom_segment(aes(x = 0, y = 50, xend = 53.3, yend = 50), color = "grey") +
  
  geom_segment(aes(x = 0, y = -10, xend = 0, yend = 60), size = 3) +
  geom_segment(aes(x = 53.3, y = -10, xend = 53.3, yend = 60), size = 3) +
  
  geom_segment(aes(x = 53.3/3, y = 0, xend = 53.3/3, yend = 60), linetype = 2) +
  geom_segment(aes(x = (53.3/3)*2, y = 0, xend = (53.3/3)*2, yend = 60), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = -10, xend = 53.3/2, yend = 0), linetype = 2) +
  
  # add yardline numbers
  annotate(geom = "text", x = 5, y = 10, label = "1 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 20, label = "2 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 30, label = "3 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 40, label = "4 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 50, label = "5 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 10, label = "1 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 20, label = "2 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 30, label = "3 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 40, label = "4 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 50, label = "5 0", angle = 90, size = 5) +
  
  annotate(geom = "text", x = 57, y = 0, label = "LOS", angle = 0, size = 6) +
  
  
  lims(x = c(0, 60), y = c(-10,60)) +
  theme_few() +
  theme(axis.text.x=element_blank(), #remove x axis labels
        axis.ticks.x=element_blank(), #remove x axis ticks
        axis.text.y=element_blank(),  #remove y axis labels
        panel.grid = element_blank(),
        axis.title = element_blank())


#### CLUSTER CATCH DISTRIBUTION MAP ####

xmin = c(53.3/2, 0, 53.3/3, (53.3/3)*2, 0, 53.3/3, (53.3/3)*2, 0, 53.3/3, (53.3/3)*2, 0)
xmax = c(53.3, 53.3/2, (53.3/3)*2, 53.3, 53.3/3, (53.3/3)*2, 53.3, 53.3/3, (53.3/3)*2, 53.3, 53.3/3)
ymin = c(-10, -10, 0, 0, 0, 10, 10, 10, 20, 20, 20)
ymax = c(0, 0, 10, 10, 10, 20, 20, 20, 60, 60, 60)

cl = clust %>% filter(cluster == 5) ## replace with any cluster number 0-7
clu = target_bins %>% filter(Player %in% cl$Player) 

cols = data.frame(colSums(clu[,-1])) %>%
  rownames_to_column("loc") %>%
  pivot_wider(names_from = loc, values_from = colSums.clu....1..) %>%
  mutate(catch_perc_screen_right = complete_screen_right/(complete_screen_right + incomplete_screen_right),
         catch_perc_screen_left = complete_screen_left/(complete_screen_left + incomplete_screen_left),
         catch_perc_short_middle = complete_short_middle/(complete_short_middle + incomplete_short_middle),
         catch_perc_short_right = complete_short_right/(complete_short_right + incomplete_short_right),
         catch_perc_short_left = complete_short_left/(complete_short_left + incomplete_short_left),
         catch_perc_mid_middle = complete_mid_middle/(complete_mid_middle + incomplete_mid_middle),
         catch_perc_mid_right = complete_mid_right/(complete_mid_right + incomplete_mid_right),
         catch_perc_mid_left = complete_mid_left/(complete_mid_left + incomplete_mid_left),
         catch_perc_long_middle = complete_long_middle/(complete_long_middle + incomplete_long_middle),
         catch_perc_long_right = complete_long_right/(complete_long_right + incomplete_long_right),
         catch_perc_long_left = complete_long_left/(complete_long_left + incomplete_long_left)) %>% 
  mutate(Player = "Cluster")

cl2 = cols[,c(23:34)] %>%
  pivot_longer(!Player, names_to = "location", values_to = "perc")
plot_dat_cl = cbind(cl2, xmin, xmax, ymin, ymax)
colnames(plot_dat_cl) = c("Player", "location", "perc", "xmin", "xmax", "ymin", "ymax")


# catch distribution
clust_catch_dist = ggplot() +
  
  #tiles
  geom_rect(data = plot_dat_cl, aes(xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax, fill = perc)) +
  scale_fill_gradient2(midpoint = 0.75, low = "gray90", mid = "gray70", high = "steelblue3") +
  
  
  # percentages
  annotate(geom = "text", x = (53.3/4)*3, y = -5, label = paste(round(cl2$perc[1]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/4, y = -5, label = paste(round(cl2$perc[2]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/2, y = 5, label = paste(round(cl2$perc[3]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = (53.3/6)*5, y = 5, label = paste(round(cl2$perc[4]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/6, y = 5, label = paste(round(cl2$perc[5]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/2, y = 15, label = paste(round(cl2$perc[6]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = (53.3/6)*5, y = 15, label = paste(round(cl2$perc[7]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/6, y = 15, label = paste(round(cl2$perc[8]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/2, y = 35, label = paste(round(cl2$perc[9]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = (53.3/6)*5, y = 35, label = paste(round(cl2$perc[10]*100, 0), "%"), size = 5) +
  annotate(geom = "text", x = 53.3/6, y = 35, label = paste(round(cl2$perc[11]*100, 0), "%"), size = 5) +
  
  
  # add field line
  geom_segment(aes(x = 0, y = 0, xend = 53.3, yend = 0), linetype = 2) +
  geom_segment(aes(x = 0, y = 10, xend = 53.3, yend = 10), linetype = 2) +
  geom_segment(aes(x = 0, y = 20, xend = 53.3, yend = 20), linetype = 2) +
  geom_segment(aes(x = 0, y = 30, xend = 53.3, yend = 30), color = "grey") +
  geom_segment(aes(x = 0, y = 40, xend = 53.3, yend = 40), color = "grey") +
  geom_segment(aes(x = 0, y = 50, xend = 53.3, yend = 50), color = "grey") +
  
  geom_segment(aes(x = 0, y = -10, xend = 0, yend = 60), size = 3) +
  geom_segment(aes(x = 53.3, y = -10, xend = 53.3, yend = 60), size = 3) +
  
  geom_segment(aes(x = 53.3/3, y = 0, xend = 53.3/3, yend = 60), linetype = 2) +
  geom_segment(aes(x = (53.3/3)*2, y = 0, xend = (53.3/3)*2, yend = 60), linetype = 2) +
  geom_segment(aes(x = 53.3/2, y = -10, xend = 53.3/2, yend = 0), linetype = 2) +
  
  # add yardline numbers
  annotate(geom = "text", x = 5, y = 10, label = "1 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 20, label = "2 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 30, label = "3 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 40, label = "4 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 5, y = 50, label = "5 0", angle = 270, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 10, label = "1 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 20, label = "2 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 30, label = "3 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 40, label = "4 0", angle = 90, size = 5) +
  annotate(geom = "text", x = 53.3-5, y = 50, label = "5 0", angle = 90, size = 5) +
  
  annotate(geom = "text", x = 57, y = 0, label = "LOS", angle = 0, size = 6) +
  
  
  lims(x = c(0, 60), y = c(-10,60)) +
  theme_few() +
  theme(axis.text.x=element_blank(), #remove x axis labels
        axis.ticks.x=element_blank(), #remove x axis ticks
        axis.text.y=element_blank(),  #remove y axis labels
        panel.grid = element_blank(),
        axis.title = element_blank())
