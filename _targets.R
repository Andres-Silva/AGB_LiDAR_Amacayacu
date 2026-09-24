setwd("~/Library/CloudStorage/GoogleDrive-andresslvdq@gmail.com/My Drive/LiDAR/AGB_LiDAR_Amacayacu")
# Load packages required to define the pipeline:
library(targets)
library(tarchetypes)
library(geotargets)


tar_option_set(
 packages = c("terra","sf",
              "tidyverse", "brms", "tidybayes", "ggplot2","quarto"))


# Run the R scripts in the R/ folder with your custom functions:
tar_source("R/functions.R")

# tar_source("other_functions.R") # Source other scripts as needed.

# Replace the target list below with your own:
list(
 tar_target(file_TLS, "data/TLS_data.csv", format = "file"),
 
 tar_target(file_plot,"data/plot_data.csv",format = "file"),
 
 tar_target(file_metrics,"data/metrics_canopy_quadrats_50m.gpkg",
            format = "file"),
 
 tar_target(file_canopy,"data/metrics_canopy_50m.tif",format = "file"),
 
 tar_target(data_TLS, get_TLS_data(file_TLS)),
 
 tar_target(data_plot,get_plot_data(file_plot)),
 
 tar_target(plot_metrics,get_plot_metrics(file_metrics)),
 
 tar_terra_rast(chm_metrics,get_ALS_raster(file_canopy)),
 
 tar_target(mod_height, fit_height_model(data_TLS)),
 
 tar_target(mod_AGB, fit_AGB_model(data_TLS)),
 
 tar_target(plot_quadrat,calculate_plot_AGB(data_plot,mod_height,mod_AGB,
                                            plot_metrics)),
 
 tar_target(mod_canopy,fit_canopy_model(plot_quadrat)),
 
 tar_terra_rast(AGB_raster,predicted_AGB(chm_metrics,mod_canopy)),
 
 tar_target(
  pred_canopy, 
  predict_response(mod_canopy, zmean_chm = seq(0, 30, length.out = 100))),
 
 tar_target(
  pred_height, 
  predict_response(mod_height, DBH = seq(1, 130, length.out = 100))),
 
 tar_target(pred_AGB, predict_observed(mod_AGB,var_name = "AGB",
                                       DBH = data_TLS$DBH,
                                       Height = data_TLS$Height,
                                       wd = data_TLS$wd,
                                       AGB = data_TLS$AGB)),
 
 tar_target(plot_allometry,plot_response(pred_height,data = data_TLS,
                                         x = DBH,y = Height,
                                         predict_x = DBH,
                                         x_label = "DBH (cm)",
                                         y_label = "Height (m)")),
 
 tar_target(plot_agb, plot_observed(pred_AGB,x = AGB,
                                    x_label = "Observed AGB (Mg)",
                                    y_label = "Predicted AGB (Mg)")),

 tar_target(plot_agb_cmh,plot_response(pred_canopy,plot_quadrat,zmean_chm,AGB,
                                         x_label = "CMH (m)",
                                         y_label = 
                                    expression("AGB Density ("~Mg~ha^{-1}~")"))),
 
 tar_quarto(name = report,path = "Quarto_report.qmd")
 
)


