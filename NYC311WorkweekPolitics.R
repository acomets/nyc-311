# NYC 311 service request data
# Antoine Comets
library(dplyr)
library(stringr)
library(chron)
library(ggplot2)
library(RColorBrewer)

# Read all the csv files into a single data frame
files <- list.files('input', '*.csv', full.names=T)
data.list <- lapply(files, read.csv)
data <- do.call(rbind, data.list)

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

############
# WORKWEEK #
############

# Define a variable time of week
clean.hours = function(x) ifelse(weekdays(x) %in% c('Saturday', 'Sunday'), 'weekend',
                                  ifelse(hours(x) %in% c(9:16), 'business hours', 'other weekday'))

data$Time.of.Week <- factor(sapply(data$Created.Date, clean.hours))

# Compute frequencies
schedule <- table(data$Incident.Zip, data$Time.of.Week) %>%
  prop.table(1) %>%
  as.data.frame.matrix

# Fit K Means
set.seed(1000)
fit <- kmeans(schedule, 3, nstart=100)
schedule <- schedule %>% mutate(region=rownames(schedule))
schedule <- data.frame(schedule, value=as.factor(fit$cluster))

# Plot (zoom on zip codes in the 5 boroughs)
data(zip.regions)
county.names <- c('new york', 'kings', 'queens', 'bronx', 'richmond')
zip.codes <- unique(zip.regions[zip.regions$state == 'new york' &
                                zip.regions$county.name %in% county.names, ]$region)

zip_choropleth(schedule,
               title="Typology of ZIP Codes",
               legend='Clusters',
               zip_zoom=intersect(schedule$region, zip.codes))

# Patterns by cluster
schedule$region <- as.factor(schedule$region)
complete.data <- data %>% left_join(schedule, by=c('Incident.Zip' = 'region'))
patterns <- table(complete.data$value, complete.data$Time.of.Week) %>%
  prop.table(1) %>%
  as.data.frame
colnames(patterns) <- c('cluster', 'type', 'freq')

ggplot(patterns, aes(cluster, freq, fill=type)) +
  geom_bar(stat="identity", position="dodge") + theme_bw() +
  scale_fill_manual(values=colorRampPalette(brewer.pal(8, "Accent"))(20)) +
  labs(title="Frequency of request throughout the week by Cluster", x="Cluster", y="Frequency")

######################
# POLITICAL BACKDROP #
######################

# Month indicator
data$Month <- as.Date(cut(data$Created.Date,
                          breaks="month"))
month <- table(data$Month)
month <- data.frame(Month=as.Date(names(month)), Freq=as.vector(month))

# Mayor tenure
data$Mayor <- ifelse(data$Created.Date < as.POSIXct("2014/01/01", tz="EST"), 'Michael Bloomberg', 'Bill de Blasio')

# Plot number of requests vs. tenure
ggplot(data, aes(Month, fill=Mayor)) +
  geom_bar() + theme_bw() +
  labs(title="Number of service request trends vs. mayor tenure", y="Count")

# Plot top 20 complaint types by mayor tenure
v <- sort(table(data$Complaint.Type), decreasing=TRUE)
d <- data.frame(word=names(v), freq=as.vector(v))
most.common.types <- head(d, 20)$word

mayor <- table(data$Mayor, data$Complaint.Type) %>%
  prop.table(1) %>%
  as.data.frame
colnames(mayor) <- c("Mayor", "Complaint.Type", "Freq")
mayor <- mayor[mayor$Complaint.Type %in% most.common.types, ]

ggplot(mayor, aes(Mayor, Freq, fill=Complaint.Type)) +
  geom_bar(stat="identity", position="dodge") + theme_bw() +
  scale_fill_manual(values=colorRampPalette(brewer.pal(8, "Accent"))(20)) +
  labs(title="Patterns of Top 20 Complaint Types by Mayor tenure", x="Mayor", y="Frequency")
