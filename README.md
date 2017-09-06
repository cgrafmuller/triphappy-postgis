# triphappy-postgis
PostGIS helpers used on https://triphappy.com

* Rails app must already have PostGIS installed
* Designed to be used when you have multiple PostGIS models, such as neighborhood shape files and points of interest within them
* To use, replace the Object model with your PostGIS DB model to be searched (e.g. points of interest)
* and add "include Postgis" into the model declaration of the object to search within (e.g. neighborhood)
* Explicitly works only with Geography data types
