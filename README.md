# Evaluating NFL WRs using KMeans & Markov Modelling

By: Ryker Moreau & Elijah Cavan

853 Final Project

___________________________________________________________________________________________________________________________________________________________
> **Note:** The **Publish now** button is disabled if your file has not been published yet.


# Introduction

The National Football League (NFL) is a place where some of the freakiest athletes ply their trade. Chief among those athletes are the players who are able to play the wide receiver (WR) and defensive back (DB -or CB for cornerback) positions. These positions are tasked with tracking and catching (or in the defense's case-preventing a catch) footballs thrown from the QB (Quarterback) and are largely considered the most impotant positions on the field (other than QB). Below is an image which helps clarify how a typical NFL football game is played:

![fig1](img/formation.png)
  
In 2020, the NFL hosted a data science competition called the NFL Big Data Bowl. They tasked competitors with determining the best defenders and wide receivers in the league, and researching what makes these players good at their job. Ryker and I (along with fellow student Brendan Kumagai) already had [some experience](https://operations.nfl.com/updates/football-ops/nfl-announces-finalists-for-fourth-annual-nfl-big-data-bowl/) with the big Data Bowl in 2022, so we decided to look at the 2020 data for our project. The approach for our project largely follows the [paper](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&ved=2ahUKEwifzoC6woz3AhXhdc0KHXFmDeEQFnoECAcQAQ&url=https%3A%2F%2Fwww.cs.sfu.ca%2F~oschulte%2Ffiles%2Fpubs%2Fsloan-fix.pdf&usg=AOvVaw0eNIlI-1tbM6Ez4AGPa7yK) of SFU professor Oliver Schulte who presented his work evaluating and clustering NHL (National Hockey League) players at the Sloan Analytics Conference- one of the largest sports analytics conferences held each year. 

His paper is titled, "Apples-to-Apples..." because he wanted to find ways to compare players who do similar actions on the ice (i.e he felt it was wrong to compare defensemen- who's primary task is to defend the net anf make outlet passes to forwards, with forwards- who's job is to keep possession of the puck and create scoring oppertunities in the attacking zone). He used the affinity propagation clustering algorithm with the available event data to create heatmaps which described where a player performs specific actions on the ice the most. After doing this, he created a metric to evaluate the players in each of the clusters using a Markov Model. The markov model helps to positively grade players who preform actions that lead to goals for their team (or prevents goals for the other team). Since some of the actions don't end up of the score sheet (a player wins a puck battle leading to a goal for their team or a defensemen chases down an opposing forward preventing a goal), Schulte's algorithm helps to find and give credit to potentially underrated players. 

Our adaptation of this problem leads to large deviations from the seminal paper. The paper [attacking contributions](https://statsbomb.com/articles/soccer/attacking-contributions-markov-models-for-football/) is a good example of how we have constructed our markov model. We have adapted these methods for a new sport- football, which has quite different positions. We decided to focus in on WRs, TEs (Tight ends) and RBs (running backs) - these are the positions that are able to catch the ball from the QB. The goal of football is that you have 4 downs to gain 10 yards (after those 10 yards your 'downs' reset) after which you change possesions with the opposing team. If you reach the opposing endzone you score a touchdown (you can also kick a field goal which is worth 3 points as opposed to 7 for the touchdown). Thus our markov model looked to credit players who make catches which extend drives (prevent change of possession states) and lead to touchdowns and field goals (these are the 3 absorbing states in our markov chain- field goal, change of possession ('drive ends') and touchdown). Here is an example of a potential "drive" (set of downs) in our data:

```mermaid
graph LR
A[1st and mid] -- QB sack --> B(2nd and long) -- incomplete pass --> C(3rd and long) -- run play --> D(4th and mid) -- punt --> E[Change of Possession]
```

For our clustering algorithm we also diverge from Schulte's paper. Whereas Schulte's affinity propagation algorithm doesn't assume an initial cluster number- our KMeans algorithm does need to have a number of clusters specificied a priori. We dealt with this by running the algorithm thousands of times using different pre-specified cluster numbers and picking the iteration where the algorithm has the smallest error.

# KMeans

For our

# Markov Model


This math is inline `a^2+b^2=c^2`.

This is on a separate line

```math
a^2+b^2=c^2
```


# Hidden Markov Models

# Results

Cluster 1:

|Player|EPA_new |EPA |
|----------------|-------------------------------|-----------------------------|
|Hopkins|2.5|2.1 |
|Dude |2.4 |2.7 |
|Dude2  |2.2|2.2|









