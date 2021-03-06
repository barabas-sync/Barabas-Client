/**
    This file is part of Barabas Client Library.

	Copyright (C) 2011 Nathan Samson
 
    Barabas Client Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Barabas Client Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Barabas Client Library.  If not, see <http://www.gnu.org/licenses/>.
*/

namespace Barabas.Client
{
	public class SyncedFileVersion : Object
	{
		private static const int COLUMN_ID = 0;
		private static const int COLUMN_FILE_ID = 1;
		private static const int COLUMN_REMOTE_ID = 2;
		private static const int COLUMN_VERSION_NAME = 3;
		private static const int COLUMN_DATETIME_EDITED = 4;
	
		public int64 ID { get; private set; }
		public int64 remoteID { get; private set; }
		public int64 fileID { get; private set; }
		public string name { get; set; }
		public DateTime datetimeEdited { get; private set; }
		
		private bool uploading_or_uploaded;
		private bool deprecated;
		
		private Database database;
	
		public SyncedFileVersion(int64 fileID,
		                         string name,
		                         DateTime datetimeEdited,
		                         Database database)
		{
			this.remoteID = 0;
			this.fileID = fileID;
			this.name = name;
			this.datetimeEdited = datetimeEdited;
			this.database = database;
			this.deprecated = false;
			this.uploading_or_uploaded = false;
			
			insert();
			upload_started.connect(() => {
				uploading_or_uploaded = true;
			});
		}
	
		public SyncedFileVersion.from_remote(int64 remoteID,
		                                     int64 fileID,
		                                     string name,
		                                     DateTime datetimeEdited,
		                                     Database database)
		{
			this.remoteID = remoteID;
			this.fileID = fileID;
			this.name = name;
			this.datetimeEdited = datetimeEdited;
			this.database = database;
			this.deprecated = false;
			this.uploading_or_uploaded = true;
			
			insert();
		}
		
		private SyncedFileVersion.from_statement(Sqlite.Statement stmt,
		                                         Database database)
		{
			this.ID = stmt.column_int64(COLUMN_ID);
			this.remoteID = stmt.column_int64(COLUMN_REMOTE_ID);
			this.fileID = stmt.column_int64(COLUMN_FILE_ID);
			this.name = stmt.column_text(COLUMN_VERSION_NAME);
			this.datetimeEdited = create_date(stmt.column_text(COLUMN_DATETIME_EDITED));
			this.database = database;
			this.deprecated = false;
			
			this.uploading_or_uploaded = (remoteID != 0);
			if (remoteID != 0)
			{
				upload_started.connect(() => {
					uploading_or_uploaded = true;
				});
			}
		}
		
		public bool is_remote()
		{
			return remoteID != 0;
		}
		
		public bool is_uploading_or_uploaded()
		{
			return remoteID != 0 || uploading_or_uploaded;
		}
		
		public void deprecate()
		{
			deprecated = true;
			remove();			
		}
		
		public bool is_deprecated()
		{
			return deprecated;
		}
		
		internal void set_remote(int64 remote_id)
		{
			this.remoteID = remote_id;
			
			Sqlite.Statement update_stmt = database.prepare("
			    UPDATE SyncedFileVersion
			           SET remoteID=@remoteID
			           WHERE ID=@ID");
			update_stmt.bind_int64(update_stmt.bind_parameter_index("@ID"), ID);
			update_stmt.bind_int64(update_stmt.bind_parameter_index("@remoteID"), remote_id);
			update_stmt.step();
		}
	
		public static Gee.List<SyncedFileVersion> find_versions_for_file(SyncedFile file, Database database)
		{
			Gee.List<SyncedFileVersion> list = new Gee.ArrayList<SyncedFileVersion>();
			
			Sqlite.Statement select = database.prepare("SELECT * FROM SyncedFileVersion
			                                            WHERE fileID=@fileID");
			select.bind_int64(select.bind_parameter_index("@fileID"), file.ID);
			
			while (select.step() == Sqlite.ROW)
			{
				list.add(new SyncedFileVersion.from_statement(select, database));
			}
			
			return list;
		}
		
		public static SyncedFileVersion? from_id(int64 id, Database database)
		{
			Sqlite.Statement select = database.prepare("SELECT * FROM SyncedFileVersion
			                                            WHERE ID=@ID");
			select.bind_int64(select.bind_parameter_index("@ID"), id);
			
			if (select.step() == Sqlite.ROW)
			{
				return new SyncedFileVersion.from_statement(select, database);
			}
			else
			{
				return null;
			}
		}
		
		public static SyncedFileVersion? find_from_remote_id(int64 remote_id, Database database)
		{
			Sqlite.Statement select = database.prepare("SELECT * FROM SyncedFileVersion
			                                            WHERE remoteID=@remoteID");
			select.bind_int64(select.bind_parameter_index("@remoteID"), remote_id);
			
			if (select.step() == Sqlite.ROW)
			{
				return new SyncedFileVersion.from_statement(select, database);
			}
			else
			{
				return null;
			}
		}
		
		public static Gee.List<SyncedFileVersion> unsynced(Database database)
		{
			Sqlite.Statement find = database.prepare("SELECT * FROM SyncedFileVersion WHERE remoteID IS NULL");
			
			Gee.List<SyncedFileVersion> list = new Gee.ArrayList<SyncedFileVersion>();
			
			while (find.step() == Sqlite.ROW)
			{
				list.add(new from_statement(find, database));
			}
			return list;
		}
		
		private void insert()
		{
			Sqlite.Statement stmt = database.prepare("INSERT INTO SyncedFileVersion
			    (fileID, remoteID, name, timeEdited) 
			    VALUES(@fileID, @remoteID, @name, @timeEdited);");
			stmt.bind_int64(stmt.bind_parameter_index("@fileID"), fileID);
			if (remoteID == 0)
			{
				stmt.bind_null(stmt.bind_parameter_index("@remoteID"));
			}
			else
			{
				stmt.bind_int64(stmt.bind_parameter_index("@remoteID"), remoteID);
			}
			stmt.bind_text(stmt.bind_parameter_index("@name"), name);
			stmt.bind_text(stmt.bind_parameter_index("@timeEdited"), datetimeEdited.format("%Y-%m-%dT%H:%M:%S%z"));
			int rc = stmt.step();
			if (rc != Sqlite.DONE)
			{
			}
			this.ID = database.last_insert_row_id();
		}
		
		private void remove()
		{
			Sqlite.Statement stmt = database.prepare("DELETE FROM SyncedFileVersion
			    WHERE ID=@ID;");
			stmt.bind_int64(stmt.bind_parameter_index("@ID"), ID);
			stmt.step();
		}
		
		private DateTime create_date(string date)
		{
			string datetimepart = date.substring(0, 19);
			int year = date.substring(0, 4).to_int();
			int month = date.substring(5, 2).to_int();
			int day = date.substring(8, 2).to_int();
			int hours = date.substring(11, 2).to_int();
			int minutes = date.substring(14, 2).to_int();
			int seconds = date.substring(17, 2).to_int();
			TimeZone timezone = new TimeZone(date.substring(19));
	
			return new DateTime(timezone,
					            year,
					            month,
					            day,
					            hours,
					            minutes,
					            seconds);
		}
		
		public signal void upload_started();
		public signal void upload_progressed(int64 progress, int64 total);
		public signal void upload_stopped();
	}
}
