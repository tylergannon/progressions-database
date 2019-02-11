#!/usr/bin/env ruby

require 'csv'
require 'sqlite3'
require 'active_support/time_with_zone'
require 'yaml'

db = SQLite3::Database.new "scripts/progressions.sqlite3"

start_date = DateTime.new(1900, 1, 1, 0, 0)
db.transaction

db.execute "drop table if exists chartRecord;"

db.execute <<-SQL
  CREATE TABLE chartRecord(
      id INTEGER PRIMARY KEY ASC,
      ephemerisPointId INTEGER NOT NULL,
      name TEXT NOT NULL,
      dob INTEGER NOT NULL,
      isMine INTEGER NOT NULL DEFAULT 0,
      yearBranch TEXT NOT NULL,
      yearStem TEXT NOT NULL,
      hourBranch TEXT NOT NULL,
      hourStem TEXT NOT NULL,
      ming TEXT NOT NULL,
      ziWei TEXT NOT NULL,
      tianFu TEXT NOT NULL,
      url TEXT,
      roddenRating TEXT
  );

SQL

db.execute "drop table if exists starComment;"

db.execute <<-SQL
CREATE TABLE starComment(
    star TEXT,
    palace TEXT ,
    comments TEXT NOT NULL,
    auspices TEXT NOT NULL DEFAULT 'Neutral',
    branch TEXT NOT NULL,
    inHouseWith TEXT NOT NULL
);

SQL

month = 2**8
day = month * 2**4
hour = day * 2**5
minute = hour * 2**5
dst = minute * 2**6

db.commit

CSV.foreach("scripts/scraper.chartRecord.csv", headers: true) do |row|
  query = <<-SQL
    INSERT OR FAIL INTO chartRecord(
          ephemerisPointId, name, dob, yearBranch, yearStem,
          hourBranch, hourStem, ming, ziWei, tianFu, url, roddenRating, isMine
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1);
  SQL
  theDate = DateTime.new(row["year"].to_i, row["monthOfYear"].to_i, row["dayOfMonth"].to_i)
  dob =
      (row["year"].to_i - 1900) +
          month * row["monthOfYear"].to_i +
          day * row["dayOfMonth"].to_i +
          hour * row["hourOfDay"].to_i +
          minute * row["minuteOfHour"].to_i +
          dst * (row["dst"] == "true" ? 1 : 0)

  params = (theDate - start_date).to_i, row["name"], dob,
      row["yearBranch"], row["yearStem"], row["hourBranch"], row["hourStem"], row["ming"], row["ziWei"],
      row["tianFu"], row["url"], row["roddenRating"]

  db.execute query, params
  $stdout.putc("#")
end

puts "\nStar Comments"

query = "INSERT OR FAIL INTO starComment(star, palace, comments, auspices, inHouseWith, branch) VALUES (?, ?, ?, ?, ?, ?);"
for file in Dir.glob("scripts/*.yml")
  data = YAML::load_file file
  data.each do |comment|
    puts comment.to_s
    branch = (comment["branch"] || []).to_s
    if branch == ""
      branch = "[]"
    end
    params = [comment["star"], comment["palace"], comment["comments"], comment["auspices"] || 'Neutral',
              comment["inHouseWith"].to_s,
              branch]

    db.execute query, params
    $stdout.putc("#")
  end
end

`zip -9 ephemerisdb scripts/progressions.sqlite3`
`mv ephemerisdb.zip app/src/main/res/raw/ephemerisdb`
