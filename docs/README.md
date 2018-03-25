# Data Set
* Original data set contains nearly 10 million individual service requests for New York City 311 from 2010 to 2017
* Randomly sampled subset containing 1.27 million records
* Each record includes information such as:
  * service request type
  * service request open/close date and time
  * location (latitude, longitude, address, zip code)
  * resolution status and description (including name of agency which handled the request)
  * additional details (park, school, bridge, taxi company, ferry)

# Data Cleaning
* Loaded the data from all 8 years into a single data frame
* Cleaned complaints (originally 280 types): format, grouped
similar types
  * Narrowed down to 230 types
* Only kept complaint types present throughout all 8 years
  * Doing this removes rare complaint types
  * Narrowed down to 125 types

Figure 1: Frequency of the different types of complaints (word cloud)
---
![Figure 1: Frequency of the different types of complaints (word cloud)](https://acomets.github.io/nyc-311/wordcloud.png)

# Neighborhood Typology
* Grouped the data by neighborhood based on zip codes
* Cleaned zip codes to keep only those corresponding to NYC,
i.e. from 10001 (Midtown) to 11697 (Rockaways)
* Only kept zip codes with more than 50 complaints
* Then we can define the **typology** of a neighborhood as the
vector of frequencies of each complaint type
* Then ran a clustering algorithm (K-means) on the
neighborhood typologies to group them into categories
* Problem: choosing the optimal number k of clusters
* ran several methods to determine the optimal number of
clusters, which yielded slightly different results: 3 for elbow
and silhouette, clear improvement up to 4 for the gap statistic
* We set **k = 4**.

Figure 2: Typology of NYC Zip Codes
---
![Figure 2: Typology of NYC zip codes](https://acomets.github.io/nyc-311/zip_typology.png)

# Results
* The clusters obtained seem to make sense
  * Cluster 1 includes Midtown and Downtown Manhattan, JFK airport
  * Cluster 2 includes Northern Manhattan, the Bronx and Central Brooklyn
  * Cluster 3 includes Southern/Eastern Brooklyn, Western Queens and
parts of Eastern Bronx
  * Cluster 4 includes Staten Island and Eastern Bronx/Queens
* Then looking at patterns in the distribution of the 20 most
common complaint types within each cluster we can see that
  * Cluster 1 has the highest frequency of noise complaints, corresponding to very busy areas
  * Cluster 2 has the highest frequency of heating and plumbing complaints, suggesting somewhat run-down neighborhoods
  * Cluster 3 exhibits most complaints about noise from residential source, heating and blocked driveways, indicating residential areas
  * Cluster 4 has the highest frequency of street condition complaints
among all clusters, reflecting more suburban neighborhoods

Figure 3: Patterns of Top 20 Complaint Types by Cluster
---
![Figure 3: Patterns of Top 20 Complaint Types by Cluster](https://acomets.github.io/nyc-311/patterns.png)

# Further Analysis
To take this analysis a step further, I could have used external data
such as census data to study correlation of those typologies with:
* Demographic and socioeconomic features: employment and
education levels, median income, ethnicity
* Housing data: real estate prices
* Public safety: crimes and felonies
* Mass transit: MTA ridership statistics, traffic incidents
* Hospital inpatient data
* Public school enrollment

# Miscellaneous
* Instead of looking at complaint type frequencies, we can also look at the distribution of requests throughout the workweek
  * Weekday business hours (9 am-5 pm)
  * Weekday outside of business hours
  * Weekend
* Again, define the vector of frequency of requests across those
time windows for each zip code area
  * Clustered the neighborhoods according to these vectors
  * This time set k = 3

Figure 4: Alternative Typology of NYC Zip Codes
---
![Figure 4: Alternative Typology of NYC zip codes](https://acomets.github.io/nyc-311/zip_workweek.png)

* Expected the frequency of requests during the campaign preceding the 2013 mayoral election (three months leading to November 5, 2013) to exhibit different behavior from normal
* While this did not seem true, the trend of overall frequency of complaints exhibit a different behavior under the two tenures

Figure 5: Number of service request trends vs. mayor tenure
---
![Figure 5: Number of service request trends vs. mayor tenure](https://acomets.github.io/nyc-311/mayor.png)
