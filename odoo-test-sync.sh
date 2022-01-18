#!/bin/bash

# Copyright (C) 2022 by Joan Arbona (joan at gotes dot org)
# Restores odoo backup to a test environment container

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


BACKUPS_PATH="/srv/backups/odoo" # Path containing sql.gz backup, in gz format
BACKUP_NAME="odoo12.sql" # Name of gz backup without the .gz
WORK_PATH="/tmp/restore" # Temporary working path

TEST_DB_CONTAINER="odoo12test_db" # Container name of the test database

TEST_BASE_PATH="/srv/docker-test/odoo12-test" # Base path of docker-compose test environment
TEST_DOCKERCOMPOSE_PATH="$TEST_BASE_PATH/docker-compose.yml" # docker-compose.yml of the test environment

PROD_DATA_FOLDER="/srv/docker/odoo12/odoo_data" # Production data folder
TEST_DATA_FOLDER="$TEST_BASE_PATH/odoo_data" # Test environment data folder

status=$(docker-compose -f "$TEST_DOCKERCOMPOSE_PATH" ps -q)
if [ ! -z "$status" ]; then 
  echo "Stopping containers... "
  docker-compose -f "$TEST_DOCKERCOMPOSE_PATH" down
  sleep 4
fi

echo "Starting DB container... "
docker-compose -f "$TEST_DOCKERCOMPOSE_PATH" up -d db
sleep 10
echo "Done"

mkdir -p $WORK_PATH
cp "$BACKUPS_PATH/$BACKUP_NAME.gz" $WORK_PATH
cd $WORK_PATH
echo "Extracting backup $BACKUPS_PATH/$BACKUP_NAME.gz to $WORK_PATH..."
gunzip "$BACKUP_NAME.gz"
echo "Done"

# Edit backup here

echo "Replacing mail server"
sed -i -e 's/in-v3.mailjet.com/no-smtp/g' $BACKUP_NAME

echo "Restoring backup to container $TEST_DB_CONTAINER..."
docker cp $BACKUP_NAME $TEST_DB_CONTAINER:/tmp
docker-compose -f "$TEST_DOCKERCOMPOSE_PATH" exec db psql -q --username=dbu_odoo -f /tmp/$BACKUP_NAME postgres > /dev/null
echo "Done"

echo "Starting WEB container... "
docker-compose -f "$TEST_DOCKERCOMPOSE_PATH" up -d web
sleep 5

echo "Change CSS color"
docker-compose -f "$TEST_DOCKERCOMPOSE_PATH" exec --user root web sed -i -e "s/#7C7BAD/#a7a7a7/g" /usr/lib/python3/dist-packages/odoo/addons/web/static/src/scss/primary_variables.scss

echo "Rsync data folder"
rsync -az "$PROD_DATA_FOLDER/" "$TEST_DATA_FOLDER/"

# Remove tmp stuff
echo "Removing tmp stuff"
rm "$WORK_PATH/$BACKUP_NAME.gz"
rm "$WORK_PATH/$BACKUP_NAME"

if [ -z "$status" ]; then 
  # Stop container if not started from beggining
  echo "Test container initially stopped. Stopping container again... "
  docker-compose -f "$TEST_DOCKERCOMPOSE_PATH" down
  echo "Done"
else
  echo "Test container initially started. Starting container again... "
  docker-compose -f "$TEST_DOCKERCOMPOSE_PATH" up -d
  echo "Done"
fi

