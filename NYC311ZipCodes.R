# NYC 311 service request data
# Antoine Comets
library(bigrquery)
library(dplyr)
library(wordcloud)
library(ggplot2)

# Installing choroplethrZip to make ZIP code maps
# install.packages("devtools")
# library(devtools)
# install_github('arilamstein/choroplethrZip@v1.5.0')
library(choroplethrZip)

#################
# DATA DOWNLOAD #
#################

nyc <- DBI::dbConnect(bigrquery::bigquery(),
                      project = "bigquery-public-data",
                      dataset = "new_york",
                      billing = "kaggle-nyc-311")

data <- nyc %>%
  tbl("311_service_requests") %>%
  select(complaint_type, created_date, incident_zip) %>%
  collect()


############
# CLEANING #
############

# Clean complaint type formats
data <- data %>%
  mutate(complaint_type = factor(gsub("[ /()-]+", "_", toupper(complaint_type))))

# Clean rare complaint types
t <- table(data$complaint_type)
rare.complaint.types <- data.frame(complaint_type=names(t), freq=as.vector(t)) %>%
  filter(freq < 50)
data <- data %>%
  filter(!(complaint_type %in% rare.complaint.types$complaint_type))
data$complaint_type <- droplevels(data$complaint_type)

# Clean ZIP codes and keep only those corresponding to NYC
data$incident_zip <- strtrim(data$incident_zip, width = 5)

zip.codes <- c(10001, 10002, 10003, 10004, 10005, 10006, 10007, 10009, 10010, 10011, 10012, 10013, 10014, 10016, 10017, 10018, 10019, 10020, 10021, 10022, 10023, 10024, 10025, 10026, 10027, 10028, 10029, 10030, 10031, 10032, 10033, 10034, 10035, 10036, 10037, 10038, 10039, 10040, 10044, 10065, 10069, 10075, 10103, 10110, 10111, 10112, 10115, 10119, 10128, 10152, 10153, 10154, 10162, 10165, 10167, 10168, 10169, 10170, 10171, 10172, 10173, 10174, 10177, 10199, 10271, 10278, 10279, 10280, 10282, 10301, 10302, 10303, 10304, 10305, 10306, 10307, 10308, 10309, 10310, 10311, 10312, 10314, 10451, 10452, 10453, 10454, 10455, 10456, 10457, 10458, 10459, 10460, 10461, 10462, 10463, 10464, 10465, 10466, 10467, 10468, 10469, 10470, 10471, 10472, 10473, 10474, 10475, 11004, 11005, 11101, 11102, 11103, 11104, 11105, 11106, 11109, 11201, 11203, 11204, 11205, 11206, 11207, 11208, 11209, 11210, 11211, 11212, 11213, 11214, 11215, 11216, 11217, 11218, 11219, 11220, 11221, 11222, 11223, 11224, 11225, 11226, 11228, 11229, 11230, 11231, 11232, 11233, 11234, 11235, 11236, 11237, 11238, 11239, 11351, 11354, 11355, 11356, 11357, 11358, 11359, 11360, 11361, 11362, 11363, 11364, 11365, 11366, 11367, 11368, 11369, 11370, 11371, 11372, 11373, 11374, 11375, 11377, 11378, 11379, 11385, 11411, 11412, 11413, 11414, 11415, 11416, 11417, 11418, 11419, 11420, 11421, 11422, 11423, 11424, 11425, 11426, 11427, 11428, 11429, 11430, 11432, 11433, 11434, 11435, 11436, 11451, 11691, 11692, 11693, 11694, 11697)

data <- data %>%
  filter(incident_zip %in% zip.codes)
data$incident_zip <- as.factor(data$incident_zip)

# Clean rare zip codes
t <- table(data$incident_zip)
rare.zip.codes <- data.frame(zip=names(t), freq=as.vector(t)) %>%
  filter(freq < 50)
data <- data %>%
  filter(!(incident_zip %in% rare.zip.codes$zip))
data$incident_zip <- droplevels(data$incident_zip)
data$complaint_type <- droplevels(data$complaint_type)


##############
# WORD CLOUD #
##############

# Type frequencies
v <- data %>%
  select(complaint_type) %>%
  table() %>%
  sort(decreasing = TRUE)

d <- data.frame(word=names(v), freq=as.vector(v))

set.seed(42)
wordcloud(words = d$word, freq = d$freq, min.freq = 1,
          max.words = 200, random.order = FALSE, rot.per = 0.35,
          colors = brewer.pal(8, "Dark2"))


#############################
# TYPOLOGY OF NEIGHBORHOODS #
#############################

# Define a typology of neighborhoods
typology <- table(data$incident_zip, data$complaint_type) %>%
  prop.table(1) %>%
  as.data.frame.matrix

# Optimal number of clusters
library(factoextra)

# Elbow method
fviz_nbclust(typology, kmeans, nstart = 100, method = "wss") +
  labs(subtitle = "Elbow method") +
  geom_vline(xintercept = 3, linetype = 2)

# Silhouette method
fviz_nbclust(typology, kmeans, nstart = 100, method = "silhouette") +
  labs(subtitle="Silhouette method")

# Gap statistic
fviz_nbclust(typology, kmeans, nstart = 100, method = "gap_stat", nboot = 50) +
  labs(subtitle = "Gap statistic method")


##########################################
# FITTING MODEL AND OUTPUT VISUALIZATION #
##########################################

# K-Means clustering
fit <- kmeans(typology, 4, nstart = 100)
typology <- typology %>%
  mutate(region = rownames(typology))
typology <- data.frame(typology, value=as.factor(fit$cluster))

# Plot (zoom on zip codes in the 5 boroughs)
zip_choropleth(typology,
               title = "Typology of ZIP Codes",
               legend = 'Clusters',
               zip_zoom = typology$region)

# Select 20 most common complaint types
most.common.types <- head(d, 20)$word

# Patterns within each cluster
typology$region <- as.factor(typology$region)
complete.data <- data %>% left_join(typology, by = c('incident_zip' = 'region'))
patterns <- table(complete.data$value, complete.data$complaint_type) %>%
  prop.table(1) %>%
  as.data.frame
colnames(patterns) <- c('cluster', 'type', 'freq')
patterns <- patterns[patterns$type %in% most.common.types, ]
patterns$type <- droplevels(patterns$type)

ggplot(patterns, aes(cluster, freq, fill = type)) +
  geom_bar(stat = "identity", position = "dodge") + theme_bw() +
  scale_fill_manual(values = colorRampPalette(brewer.pal(8, "Accent"))(20)) +
  labs(title = "Patterns of Top 20 Complaint Types by Cluster", x = "Cluster", y = "Frequency")

