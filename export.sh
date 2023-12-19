#!/bin/bash

# Variables
MYSQL_ROOT_PASSWORD="password"  # Replace with your MySQL root password
OUTPUT_DIR="data"                    # Output directory for CSV files


docker-compose up -d


# Wait for MySQL to be ready
echo "Waiting for MySQL to initialize..."
until docker-compose exec -T mysql mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent; do
    echo "Waiting for database connection..."
    sleep 1
done

docker-compose stop


# Start MySQL using Docker Compose
docker-compose up -d

# Wait for MySQL to be ready
echo "Waiting for MySQL to start..."
until docker-compose exec -T mysql mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" --silent; do
    echo "Waiting for database connection..."
    sleep 1
done

echo "Optimizing MySQL configuration..."
# Disable autocommit, foreign key checks, and unique checks
docker-compose exec -T mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "
SET autocommit=0;
SET unique_checks=0;
SET foreign_key_checks=0;
"

# Process each SQL file
for SQL_FILE in ./sql/*; do
     DATABASE_NAME=$(basename $SQL_FILE .sql) # Database name from SQL file name
    CSV_FOLDER=$OUTPUT_DIR/$DATABASE_NAME    # Folder for CSV files for this database

    # Create a folder for each database's CSV files
    mkdir -p "$CSV_FOLDER"

    # Import SQL file into the database
    echo "Creating database $DATABASE_NAME and importing data..."
    docker-compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $DATABASE_NAME;"
    echo "Importing $SQL_FILE..."
    docker-compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -D "$DATABASE_NAME" < "$SQL_FILE"

    # Get list of tables in the database
    TABLES=$(docker-compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -D "$DATABASE_NAME" -e "SHOW TABLES;" | awk 'NR>1')

    echo "$TABLES";

    # Export each table to a CSV file
    for TABLE in $TABLES; do
        CSV_FILE="$DATABASE_NAME/$TABLE.csv"
        docker-compose exec -T mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD -D "$DATABASE_NAME" -e "SELECT * INTO OUTFILE '/var/lib/mysql-files/$CSV_FILE' FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\n' FROM $TABLE;"
    done

done

# Clean-up: Stop the MySQL service
# docker-compose down

echo "CSV files have been created and zipped in the $OUTPUT_DIR directory."
