require(BIOMASS)
require(sf)
require(tidyverse)

setwd("~/Desktop/Amacayacu_2026")

data_dir<-"/Users/andressilva/Library/CloudStorage/GoogleDrive-andresslvdq@gmail.com/My Drive/LiDAR/AGB/data"

plot_table<-read.csv( "amafull_2026-02-24.csv")

sp_table<-read.csv("species.20260224.csv")


plot_df<-left_join(plot_table,sp_table,by = "spcode") |> 
 mutate(plot_id = "Amacayacu_1") |> 
 filter(status4 == "alive") |> 
 filter(!is.na(dbh4)) |> 
 separate(species,c("genus","epitet"),
          sep = " ") |> 
 mutate(genus = str_to_title(genus),
        family = str_to_title(family))


#Wood density imputation
wd<-getWoodDensity(genus = plot_df$genus,species = plot_df$epitet,
               family = plot_df$family,stand = plot_df$quadrat)

plot_df$wd<-wd$meanWD
plot_df$level_wd<-wd$levelWD

#Plot coordinates
plot_corner <- 
 read_csv("/Users/andressilva/Desktop/AMACAYACU_ALS/quadrants/plot_pt.csv")

#Check plot coordinates
check_plot <-  check_plot_coord(
 corner_data = plot_corner,
 rel_coord = c("x_rel_m", "y_rel_m"),
 proj_coord = c("rover_easting_utm_m", "rover_northing_utm_m"),
 trust_GPS_corners = TRUE,
 tree_data = plot_df,
 plot_ID = "plot_id", 
 tree_plot_ID = "plot_id",
 tree_coords = c("gx", "gy"))

#Divide plots in 50 x 50 m quadrants
plot_divide <- BIOMASS::divide_plot(
 corner_data = check_plot$corner_coord,
 rel_coord = c("x_rel", "y_rel"),
 proj_coord = c("x_proj", "y_proj"),
 longlat = NULL,
 grid_size = 50,
 grid_tol = 1,
 tree_data = check_plot$tree_data,
 tree_coords = c("x_rel", "y_rel"))


df <- plot_divide$tree_data %>% 
 mutate(
  x_utm = x_proj,
  y_utm = y_proj) %>% 
 filter(!is.na(x_proj), !is.na(y_proj)) %>% 
 st_as_sf(., coords = c("x_proj", "y_proj"),
          crs = unique(plot_corner$crs_epsg)) |> 
 st_transform(crs = "epsg:9377") 

tree_coordinates<-st_coordinates(df)

df$proj_X<-tree_coordinates[,1]
df$proj_Y<-tree_coordinates[,2]

# write.csv(df |> st_drop_geometry(),
#           paste(data_dir,"plot_data.csv",sep = "/"),row.names = F)

TLS_data<-read.csv(paste(data_dir,"AMA_data_3p.csv",sep = "/")) |> 
 select(stemtag,Height,DAP_correg,Volume)

TLS_data<-left_join(TLS_data,df |> st_drop_geometry() |> 
                     select(stemtag,wd,level_wd),by = "stemtag") |> 
 rename(DBH = DAP_correg) |> 
 mutate(AGB = (Volume*wd*1000)/1000)

write.csv(TLS_data,
          paste(data_dir,"TLS_data.csv",sep = "/"),
          row.names = F)
