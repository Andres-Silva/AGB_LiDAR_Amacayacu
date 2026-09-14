
#Read plot inventory data
get_plot_data<-function(file){
 read.csv(file)}

#Read TLS segmented data
get_TLS_data<-function(file){
 read.csv(file)}

#Read plot metric data
#ALS processing
get_plot_metrics<-function(layer){
 read_sf(layer)
 }

#Read canopy related variables (50 m)
get_ALS_raster<-function(layer){
 rast(layer)}

#Height - DBH Allometry models
fit_height_model<-function(data){
 #Functional form
 #Weibull model
 formula<-bf(
  Height ~ a*(1-exp(-b*DBH^c)),
  a ~ 1, b ~ 1, c ~ 1,
  nl = TRUE)
 
 #Prior definition
 prior_nonlinear <- c(
  set_prior("normal(40, 20)", nlpar = "a",lb = 0),
  set_prior("normal(0.05, 0.5)", nlpar = "b",lb = 0), 
  set_prior("normal(0.85, 0.4)",  nlpar = "c",lb = 0))
 
 model <- brm(
  formula = formula,
  data    = data,
  #Normal likelihood
  family  = gaussian(),
  prior   = prior_nonlinear,
  #Markov chains
  chains  = 4,
  #Iteration per chain
  iter = 5000,
  #Warm up value per chain
  warmup = 1000,
  cores = 4,
  backend = "cmdstanr",
  file_refit = "on_change"
 )}

#Fit AGB TLS model
fit_AGB_model<-function(data){
 formula<-bf(
  AGB ~ a*(wd*DBH*Height)^b,
  a ~ 1, b ~ 1,
  nl = TRUE)
 
 prior_nonlinear  = c(
  set_prior("normal(1, 10)", nlpar = "a", lb = 0),
  set_prior("normal(1,10)",   nlpar = "b",lb = 0))
 
 AGB_model <- brm(
  formula,
  data,
  family = Gamma(link = "identity"),
  prior = prior_nonlinear,
  chains = 4,
  iter   = 5000,
  warmup = 1000,
  backend = "cmdstanr",
  file_refit = "on_change")
}


#Estimate tree inventory AGB
calculate_plot_AGB<-function(plot_data,
                             Height_model,
                             AGB_model,
                             plot_metrics){
 plot_data<-plot_data |> 
  mutate(DBH = dbh4/10)
 
 plot_data$Height<-posterior_predict(object = Height_model,  
                                newdata = plot_data,
                                ndraws = 100,cores = 4) |> 
               apply(MARGIN = 2,median)
 
 plot_data$AGB<-posterior_predict(object = AGB_model,  
                                     newdata = plot_data,
                                     ndraws = 100,cores = 4) |> 
  apply(MARGIN = 2,median)
 
 AGB_quad<-plot_data |> group_by(subplot_ID) |> 
  reframe(AGB = sum(AGB)*4) |> 
  inner_join(plot_metrics,by = "subplot_ID")
 
 return(AGB_quad)}

#AGB ~ CHM model

fit_canopy_model<-function(quadrat_data){
 AGB_lognormal<-brm(formula = AGB~zmean_chm,
                    data = quadrat_data,
                    family = lognormal(link = "identity"),
                    cores = 4,
                    iter   = 5000,
                    warmup = 1000,
                    backend = "cmdstanr",
                    file_refit = "on_change")
}

#AGB prediction

predicted_AGB<-function(ALS_data,AGB_canopy_model){
 ALS_df<-terra::as.data.frame(ALS_data,xy = T,cells = T)
 
 AGB_values<-tidybayes::add_epred_draws(object = AGB_canopy_model,
                                 newdata = ALS_df,
                                 ndraws = 100,
                                 value = c(".epred")) |> 
  group_by(cell) |> 
  reframe(AGB = mean(.epred),
          AGB_sd = sd(.epred)) |> 
  select(AGB,AGB_sd,cell)
 
 AGB_predict<-inner_join(ALS_df,AGB_values,by = "cell") |> 
  select(-cell)
 
 AGB_raster<-rast(AGB_predict,type = "xyz",crs = "epsg:9377")

}

#Predict credible intervals

predict_response <- function(model, ...) {
 predict_data <- expand_grid(...) |> 
  add_predicted_draws(model, ndraws = 1000) |> 
  median_qi()
 
 return(predict_data)
}


#Plot responses
plot_response<- function(predict_data,data,x,y,predict_x,x_label,
                         y_label){
 ggplot()+
  geom_point(data = data,aes(x = {{x}}, 
                                y = {{y}}),
             alpha = 0.4)+
  geom_line(data = predict_data,aes(x = {{x}},
                                    y = .prediction))+
  geom_ribbon(data = predict_data,aes(x = {{x}},
                                      ymin = .lower,
                                      ymax = .upper),
              alpha = 0.2)+
  xlab(x_label)+
  ylab(y_label)+
   theme_bw()}

