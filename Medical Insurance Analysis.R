## Install packages if not present
install_if_missing <- function(pkg_name) {
  if (!pkg_name %in% installed.packages()) {
    message(paste("Installing package:", pkg_name))
    install.packages(pkg_name)
  } else {
    message(paste(pkg_name, "is already installed"))
  }
  # Load the package
  library(pkg_name, character.only = TRUE)
}

# library imports
install_if_missing("dplyr")
install_if_missing("ggplot2")
install_if_missing("reshape2")
install_if_missing("GGally")
install_if_missing("car")
install_if_missing("tidyr")

## data cleaning and preparation

# load data
### data set #1
# load data
ins_data = read.csv("insurance.csv",header=T)

# remove four-cat variable
ins_data <- subset(ins_data,select=-c(region))

# check for missing and duplicated data
sum(is.na(ins_data)) # returns 0
sum(duplicated(ins_data)) # returns 1
ins_data <- unique(ins_data) # remove duplicate

# transform cat into numerical
ins_data$sex <- gsub("female","1",ins_data$sex)
ins_data$sex <- gsub("male","0",ins_data$sex) 
ins_data$smoker <- gsub("yes","1",ins_data$smoker)
ins_data$smoker <- gsub("no","0",ins_data$smoker)

ins_data$sex <- as.numeric(ins_data$sex) 
ins_data$smoker <- as.numeric(ins_data$smoker) 

plot(ins_data)
cor(ins_data)

model <- lm(charges~.,ins_data)
summary(model)

## handle station operator categories

# function for replacing characters with binary
replace_word_with_binary <- function(word, vector) {
  # Convert vector to logical values: 1 if the word is found, 0 otherwise
  binary_vector <- ifelse(vector == word, 1, 0)
  return(binary_vector)
}


#Utility functions

scatter_matrix <- function(data, response_var = "y") {
  # Check if response_var exists
  if (!(response_var %in% names(data))) {
    stop("Response variable '", response_var, "' not found in the dataset.")
  }
  
  # Select numeric predictors (excluding response_var)
  numeric_vars <- data %>% 
    select(where(is.numeric)) %>% 
    names()
  
  predictors <- setdiff(numeric_vars, response_var)
  
  # Check if there are predictors
  if (length(predictors) == 0) {
    stop("No numeric predictors found (excluding the response variable).")
  }
  
  # Reshape data for faceting
  plot_data <- data %>%
    select(all_of(c(response_var, predictors))) %>%
    pivot_longer(
      cols = all_of(predictors),
      names_to = "predictor",
      values_to = "value"
    )
  
  # Generate scatterplots
  ggplot(plot_data, aes(x = value, y = .data[[response_var]])) +
    geom_point(alpha = 0.3, color = "steelblue") +
    geom_smooth(method = "lm", se = FALSE, color = "red") +  # Add regression line
    facet_wrap(~ predictor, scales = "free_x") +  # One panel per predictor
    labs(
      title = paste("Scatterplots of", response_var, "vs. Predictors"),
      x = "Predictor Value",
      y = response_var
    ) +
    theme_minimal() +
    theme(
      strip.background = element_rect(fill = "lightgray"),
      panel.spacing = unit(1, "lines")
    )
}

refined_data <- ins_data
#
#Scale data
scaled_data <- scale(refined_data[, sapply(refined_data, is.numeric)])%>% 
  as.data.frame()
head(scaled_data)

#Split Data
#num_groups <- 3
group_labels <- rep(1:3, length.out = nrow(refined_data))
group_labels <- sample(group_labels) # shuffle labels
data_groups <- data.frame(Value = refined_data, Group = group_labels)

train_data <- subset(data_groups , Group != 1)
test_data <- subset(data_groups, Group == 1)

train_data <- na.omit(train_data[, !(names(train_data) %in% c("Group"))])
test_data <- na.omit(test_data[, !(names(test_data) %in% c("Group"))])
train_data <- train_data %>%
  mutate(across(where(is.numeric), ~ ifelse(is.infinite(.) | is.nan(.), NA, .))) %>%  # Convert Inf/NaN to NA
  na.omit()

test_data <- test_data %>%
  mutate(across(where(is.numeric), ~ ifelse(is.infinite(.) | is.nan(.), NA, .))) %>%  # Convert Inf/NaN to NA
  na.omit()

refined_data


#Analysis 1 - Correlation matrix & Scatter Plots
# Select only numeric columns and compute correlation
print_correlation <- function(refined_data) {
  cor_matrix <- refined_data %>%
    select(where(is.numeric)) %>%
    cor(use = "complete.obs")  
  
  melted_cor <- melt(cor_matrix)
  
  # Create heatmap
  ggplot(melted_cor, aes(Var1, Var2, fill = value)) +
    geom_tile(color = "white") +
    scale_fill_gradient2(low = "blue", high = "red", mid = "white", 
                         midpoint = 0, limit = c(-1,1), space = "Lab", 
                         name="Correlation") +
    theme_minimal() + 
    theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1)) +
    coord_fixed() +
    geom_text(aes(label = round(value, 2)), color = "black", size = 3)
}

target <- "Value.charges"

#Analysis 1 results
print_correlation(refined_data)
print_correlation(scaled_data)
#No change in correlation due to scaling

scatter_matrix(train_data,target)

#Analysis 2: Fit model and check for Null hypothesis that all the parameters are insignificant


head(train_data)

# Fit the linear regression model
formula <- as.formula(paste(target, "~ ."))
model <- lm(formula, data = train_data)
View(train_data)

print(refined_data)
# Summarize the model
summary(model)
anova(model)
# Calculate 95% confidence intervals for the coefficients
conf_intervals <- confint(model, level = 0.95)
print(conf_intervals)

test_data$y_hat <- predict(model, newdata = test_data)

step_model <- step(model, 
                   direction = "backward")

summary(step_model)
anova(step_model)
test_data$y_hat_step <- predict(step_model, newdata = test_data)
head(test_data[, c(target, "y_hat","y_hat_step")])

#Analysis 3: Build an interaction model and step down
formula <- as.formula(paste(target, "~ .^2")) 
full_model_interaction <- lm(formula, data = train_data)  
# Summarize the model
summary(full_model_interaction)

step_model2 <- step(full_model_interaction,direction = "backward")
summary(step_model2)
#Computationally expensive!
test_data$y_hat_full_model_interaction <- predict(full_model_interaction, newdata = test_data)
test_data$y_hat_full_model_interaction_step <- predict(step_model2, newdata = test_data)
head(test_data[, c(target, "y_hat","y_hat_step","y_hat_full_model_interaction","y_hat_full_model_interaction_step")])

#Analysis 4: Get Residual Plots
check_residuals<-function(model){
  # Residuals vs Fitted with smoother
  residualPlot(model)
  
  # Q-Q Plot with confidence bands
  qqPlot(model$residuals)
}

check_residuals(model)
check_residuals(step_model)
check_residuals(full_model_interaction)
check_residuals(step_model2)


#Analysis 5: Check Hii aka Influence Diagnostics
analyze_influence <- function(model){
  influence_stats <- influence.measures(model)
  summary(influence_stats)
}
analyze_influence(model)
analyze_influence(step_model)
analyze_influence(full_model_interaction)
analyze_influence(step_model2)


#Analysis 6: Multicollinearity Check: VIF
check_VIF <- function(model, model_name) {
  vif_values <- car::vif(model)
  print(model_name)
  print(vif_values) 
  
  # Get names of predictors with VIF >= 5
  high_vif <- names(vif_values)[vif_values >= 5]  # Directly use names
  
  if(length(high_vif) > 0) {
    print(paste("High VIF predictors:", paste(high_vif, collapse = ", ")))
  } else {
    print("No predictors with VIF ≥ 5")
  }
  
  # Create barplot with names
  barplot(vif_values,
          horiz = TRUE,
          col = ifelse(vif_values >= 5, "salmon", "lightblue"),  # Color high VIF
          main = paste("VIF Values:", model_name), 
          xlab = "VIF",
          las = 1,
          names.arg = names(vif_values),  # Ensure names appear
          cex.names = 0.8  # Adjust text size if needed
  )
  abline(v = 5, col = "red", lty = 2)  # Threshold line
}

check_VIF(model,deparse(substitute(model)))
check_VIF(step_model,deparse(substitute(step_model)))
#check_VIF(full_model_interaction,deparse(substitute(full_model_interaction)))
#check_VIF(step_model2,deparse(substitute(step_model2)))


display_model_summary<- function(model) {
  print(summary(model))
  anova(model)
}

#Summarize analyses

display_model_summary(model)
display_model_summary(step_model)
display_model_summary(full_model_interaction)
display_model_summary(step_model2)


