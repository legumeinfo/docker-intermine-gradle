-- Note: This script is only run if the data directory is empty
-- (i.e., not if the volume has been populated).

CREATE DATABASE "mine";
CREATE DATABASE "items-mine";
CREATE DATABASE "userprofile-mine";
-- These would usually contain the name of the mine instead of "mine" but we
-- simplify it as we'll only have one database per mine instance.
