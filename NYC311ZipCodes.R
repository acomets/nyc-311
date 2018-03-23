# NYC 311 service request data
# Antoine Comets
library(dplyr)
library(chron)
library(stringr)
library(wordcloud)
library(ggplot2)

# Installing choroplethrZip to make ZIP code maps
# install.packages("devtools")
# library(devtools)
# install_github('arilamstein/choroplethrZip@v1.5.0')
library(choroplethrZip)

# Read all the csv files into a list of data frames
files <- list.files('input', '*.csv', full.names=T)
data.list <- lapply(files, read.csv)

# Number of service calls in each year
data.frame(year=2010:2017, n.complaints=sapply(data.list, nrow))

# Aggregate the data into a single data frame
data <- do.call(rbind, data.list)

str(data)


############
# Cleaning #
############

# Clean complaint types
clean.complaint.types <- sapply(data$Complaint.Type, str_to_title)
clean.complaint.types[grepl("Advocate", clean.complaint.types)] <- "Advocate"
clean.complaint.types[grepl("Broken *. Meter", clean.complaint.types)] <- "Broken Parking Meter"
clean.complaint.types[grepl("Dead.* Tree", clean.complaint.types)] <- "Dead Tree"
clean.complaint.types[grepl("Derelict Vehicle", clean.complaint.types)] <- "Derelict Vehicle"
clean.complaint.types[grepl("Dof Parking", clean.complaint.types)] <- "DOF Parking"
clean.complaint.types[grepl("Dof Property", clean.complaint.types)] <- "DOF Property"
clean.complaint.types[grepl("Ferry", clean.complaint.types)] <- "Ferry"
clean.complaint.types[grepl("Fire Alarm", clean.complaint.types)] <- "Fire Alarm"
clean.complaint.types[grepl("For Hire Vehicle", clean.complaint.types)] <- "For Hire Vehicle"
clean.complaint.types[grepl("Hazardous Material|Hazmat", clean.complaint.types)] <- "Hazardous Material"
clean.complaint.types[grepl("Heat", clean.complaint.types)] <- "Heating"
clean.complaint.types[grepl("Highway Sign", clean.complaint.types)] <- "Highway Sign"
clean.complaint.types[grepl("Home Delivered Meal", clean.complaint.types)] <- "Home Delivered Meal"
clean.complaint.types[grepl("Overflowing .* Basket|Adopt-A-Basket", clean.complaint.types)] <- "Overflowing Litter Basket"
clean.complaint.types[grepl("Paint", clean.complaint.types)] <- "Paint/Plaster"
clean.complaint.types[grepl("Plumbing|Leak", clean.complaint.types)] <- "Plumbing"
clean.complaint.types[grepl("Street Sign", clean.complaint.types)] <- "Street Sign"
clean.complaint.types[grepl("Sweeping", clean.complaint.types)] <- "Sweeping"
data$Complaint.Type <- factor(clean.complaint.types)

# Convert dates created into POSIXct
data$Created.Date <- as.POSIXct(data$Created.Date, format="%m/%d/%Y %I:%M:%S %p", tz="EST")

# Keep only complaint types present in all 8 years
data$Year <- years(data$Created.Date)
common.types <- Reduce(intersect, lapply(split(data, data$Year), function(x) unique(x$Complaint.Type)))
data <- data[data$Complaint.Type %in% common.types, ]
data$Complaint.Type <- droplevels(data$Complaint.Type)

# Clean ZIP codes and keep only from 10001 (Midtown) to 11697 (Rockaways)
data$Incident.Zip <- strtrim(data$Incident.Zip, width=5)
data <- data[data$Incident.Zip %in% c(10001:11697), ]
data$Incident.Zip <- as.factor(data$Incident.Zip)

# Clean rare zip codes
t <- table(data$Incident.Zip)
rare.zip.codes <- data.frame(zip=names(t), freq=as.vector(t)) %>%
  filter(freq < 50)
data <- data[!(data$Incident.Zip %in% rare.zip.codes$zip), ]
data$Incident.Zip <- droplevels(data$Incident.Zip)
data$Complaint.Type <- droplevels(data$Complaint.Type)


##############
# WORD CLOUD #
##############

# Type frequencies
v <- sort(table(data$Complaint.Type), decreasing=TRUE)
d <- data.frame(word=names(v), freq=as.vector(v))

set.seed(42)
wordcloud(words=d$word, freq=d$freq, min.freq=1,
          max.words=200, random.order=FALSE, rot.per=0.35,
          colors=brewer.pal(8, "Dark2"))


#############################
# TYPOLOGY OF NEIGHBORHOODS #
#############################

# Define a typology of neighborhoods
typology <- table(data$Incident.Zip, data$Complaint.Type) %>%
  prop.table(1) %>%
  as.data.frame.matrix

# Optimal number of clusters
library(factoextra)

# Elbow method
fviz_nbclust(typology, kmeans, nstart=100, method="wss") +
  labs(subtitle = "Elbow method") +
  geom_vline(xintercept = 3, linetype = 2)

# Silhouette method
fviz_nbclust(typology, kmeans, nstart=100, method="silhouette") +
  labs(subtitle="Silhouette method")

# Gap statistic
set.seed(42)
fviz_nbclust(typology, kmeans, nstart=100, method="gap_stat", nboot=50) +
  labs(subtitle = "Gap statistic method")


##########################################
# FITTING MODEL AND OUTPUT VISUALIZATION #
##########################################

# K-Means clustering
set.seed(1)
fit <- kmeans(typology, 4, nstart=100)
typology <- typology %>% mutate(region=rownames(typology))
typology <- data.frame(typology, value=as.factor(fit$cluster))

# Plot (zoom on zip codes in the 5 boroughs)
data(zip.regions)
county.names <- c('new york', 'kings', 'queens', 'bronx', 'richmond')
zip.codes <- unique(zip.regions[zip.regions$state == 'new york' &
                                zip.regions$county.name %in% county.names, ]$region)

zip_choropleth(typology,
               title="Typology of ZIP Codes",
               legend='Clusters',
               zip_zoom=intersect(typology$region, zip.codes))

# Select 20 most common complaint types
most.common.types <- head(d, 20)$word

# Patterns within each cluster
typology$region <- as.factor(typology$region)
complete.data <- data %>% left_join(typology, by=c('Incident.Zip' = 'region'))
patterns <- table(complete.data$value, complete.data$Complaint.Type) %>%
  prop.table(1) %>%
  as.data.frame
colnames(patterns) <- c('cluster', 'type', 'freq')
patterns <- patterns[patterns$type %in% most.common.types, ]
patterns$type <- droplevels(patterns$type)

ggplot(patterns, aes(cluster, freq, fill=type)) +
  geom_bar(stat="identity", position="dodge") + theme_bw() +
  scale_fill_manual(values=colorRampPalette(brewer.pal(8, "Accent"))(20)) +
  labs(title="Patterns of Top 20 Complaint Types by Cluster", x="Cluster", y="Frequency")

