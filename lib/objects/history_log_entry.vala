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
	class HistoryLogEntry
	{
		public int64 remoteLogID { get; private set; }
		public int64 fileRemoteID { get; private set; }
		public int64? versionID { get; private set; }
		public string? tag { get; private set; }
		public bool is_new { get; private set; }
		public int64 ts { get; private set; }
		public bool local { get; private set; }
		
		private Database database;
		
		private static int COLUMN_LOG_ID = 0;
		private static int COLUMN_FILE_ID = 1;
		private static int COLUMN_VERSION_ID = 2;
		private static int COLUMN_TAG = 3;
		private static int COLUMN_IS_NEW = 4;
		private static int COLUMN_TIMESTAMP = 5;
		private static int COLUMN_IS_LOCAL = 6;

		public HistoryLogEntry.from_new_file(int64 remoteLogID,
		                                     int64 fileRemoteID,
		                                     bool local,
		                                     Database database)
		{
			this.remoteLogID = remoteLogID;
			this.fileRemoteID = fileRemoteID;
			this.versionID = null;
			this.tag = null;
			this.is_new = true;
			this.ts = 0;
			this.local = local;
			this.database = database;
			
			insert();
		}
	
		public HistoryLogEntry.from_new_tag(int64 remoteLogID,
		                                    int64 fileRemoteID,
		                                    string tag,
		                                    bool local,
		                                    Database database)
		{
			this.remoteLogID = remoteLogID;
			this.fileRemoteID = fileRemoteID;
			this.versionID = null;
			this.tag = tag;
			this.is_new = true;
			this.ts = 0;
			this.local = local;
			this.database = database;
			
			insert();
		}
		
		public HistoryLogEntry.from_remove_tag(int64 remoteLogID,
		                                       int64 fileRemoteID,
		                                       string tag,
		                                       bool local,
		                                       Database database)
		{
			this.remoteLogID = remoteLogID;
			this.fileRemoteID = fileRemoteID;
			this.versionID = null;
			this.tag = tag;
			this.is_new = false;
			this.ts = 0;
			this.local = local;
			this.database = database;
			
			insert();
		}
		
		public HistoryLogEntry.from_new_version(int64 remoteLogID,
		                                        int64 fileRemoteID,
		                                        int64 fileVersionID,
		                                        bool local,
		                                        Database database)
		{
			this.remoteLogID = remoteLogID;
			this.fileRemoteID = fileRemoteID;
			this.versionID = fileVersionID;
			this.tag = null;
			this.is_new = true;
			this.ts = 0;
			this.local = local;
			this.database = database;
			
			insert();
		}
	
		private HistoryLogEntry.from_database(Sqlite.Statement statement,
		                                      Database database)
		{
			this.remoteLogID = statement.column_int64(COLUMN_LOG_ID);
			this.fileRemoteID = statement.column_int(COLUMN_FILE_ID);
			this.versionID = statement.column_int(COLUMN_VERSION_ID);
			this.tag = statement.column_text(COLUMN_TAG);
			this.is_new = statement.column_int(COLUMN_IS_NEW) != 0;
			this.ts = statement.column_int(COLUMN_TIMESTAMP);
			this.local = statement.column_int(COLUMN_IS_LOCAL) != 0;
			this.database = database;
		}

		public static int64 find_latest_non_local(Database database)
		{
			var find_stmt = database.prepare("SELECT MAX(remoteLogID) FROM HistoryLog
				WHERE local=0;");
			if (find_stmt.step() == Sqlite.ROW)
			{
				return find_stmt.column_int64(0);
			}
			else
			{
				return 0;
			}
		}
	
		public static HistoryLogEntry? find_by_remote(int64 remote, Database database)
		{
			var find_stmt = database.prepare("SELECT  FROM HistoryLog
				WHERE remoteLogID=@remoteLogID;");
			find_stmt.bind_int64(find_stmt.bind_parameter_index("@remoteLogID"), remote);
			if (find_stmt.step() == Sqlite.ROW)
			{
				return new HistoryLogEntry.from_database(find_stmt, database);
			}
			else
			{
				return null;
			}
		}
		
		private void insert()
		{
			var insert_stmt = database.prepare("INSERT INTO HistoryLog
				      (remoteLogID, fileRemoteID, versionID, tagName, isNew, ts, local)
				VALUES(@remoteLogID, @fileRemoteID, @versionID, @tagName, @isNew, @ts, @local);");
			insert_stmt.bind_int64(insert_stmt.bind_parameter_index("@remoteLogID"), remoteLogID);
			insert_stmt.bind_int64(insert_stmt.bind_parameter_index("@fileRemoteID"), fileRemoteID);
			if (versionID != null)
			{
				insert_stmt.bind_int64(insert_stmt.bind_parameter_index("@versionID"), versionID);
			}
			else
			{
				insert_stmt.bind_null(insert_stmt.bind_parameter_index("@versionID"));
			}
			if (tag != null)
			{
				insert_stmt.bind_text(insert_stmt.bind_parameter_index("@tagName"), tag);
			}
			else
			{
				insert_stmt.bind_null(insert_stmt.bind_parameter_index("@tagName"));
			}
			insert_stmt.bind_int(insert_stmt.bind_parameter_index("@isNew"), is_new ? 1 : 0);
			insert_stmt.bind_int64(insert_stmt.bind_parameter_index("@ts"), ts);
			insert_stmt.bind_int(insert_stmt.bind_parameter_index("@local"), local ? 1 : 0);
			int rc = insert_stmt.step();
			if (rc != Sqlite.OK)
			{
				GLib.log("error", LogLevelFlags.LEVEL_WARNING, "ERROR IN STAMENENT: %s", database.errmsg());
			}
		}
	}
}
