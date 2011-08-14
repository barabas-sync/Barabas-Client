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
		public bool is_new { get; private set; }
		public bool is_local { get; private set; }
		
		public string? fileName { get; private set; }
		public string? mimetype { get; private set; }
		
		public string? tag { get; private set; }
		
		public int64? versionRemoteID { get; private set; }
		public string? versionName { get; private set; }
		public string? timeEditedAsString { get; private set; }
		
		private Database database;
		
		private static int COLUMN_LOG_ID = 0;
		private static int COLUMN_REMOTE_FILE_ID = 1;
		private static int COLUMN_IS_NEW = 2;
		private static int COLUMN_IS_LOCAL = 3;
		
		private static int COLUMN_FILENAME = 4 ;
		private static int COLUMN_MIMETYPE = 5;
		
		private static int COLUMN_TAGNAME = 6;
		
		private static int COLUMN_VERSION_REMOTE_ID = 7;
		private static int COLUMN_VERSION_NAME = 8;
		private static int COLUMN_VERSION_TIMEEDITED = 9;

		public HistoryLogEntry.from_new_file(int64 remoteLogID,
		                                     int64 fileRemoteID,
		                                     string name,
		                                     string mimetype,
		                                     bool local,
		                                     Database database)
		{
			this.database = database;
			this.remoteLogID = remoteLogID;
			this.fileRemoteID = fileRemoteID;
			this.is_new = true;
			this.is_local = local;
			
			this.fileName = name;
			this.mimetype = mimetype;
			
			this.tag = null;
			this.versionRemoteID = null;
			this.versionName = null;
			this.timeEditedAsString = null;
			
			insert();
		}
	
		public HistoryLogEntry.from_new_tag(int64 remoteLogID,
		                                    int64 fileRemoteID,
		                                    string tag,
		                                    bool local,
		                                    Database database)
		{
			this.database = database;
			this.remoteLogID = remoteLogID;
			this.fileRemoteID = fileRemoteID;
			this.is_new = true;
			this.is_local = local;
			
			this.tag = tag;
			
			this.fileName = null;
			this.mimetype = null;
			this.versionRemoteID = null;
			this.versionName = null;
			this.timeEditedAsString = null;
			
			insert();
		}
		
		public HistoryLogEntry.from_remove_tag(int64 remoteLogID,
		                                       int64 fileRemoteID,
		                                       string tag,
		                                       bool local,
		                                       Database database)
		{
			this.database = database;
			this.remoteLogID = remoteLogID;
			this.fileRemoteID = fileRemoteID;
			this.is_new = false;
			this.is_local = local;
			
			this.tag = tag;
			
			this.fileName = null;
			this.mimetype = null;
			this.versionRemoteID = null;
			this.versionName = null;
			this.timeEditedAsString = null;
			
			insert();
		}
		
		public HistoryLogEntry.from_new_version(int64 remoteLogID,
		                                        int64 fileRemoteID,
		                                        int64 fileVersionID,
		                                        string versionName,
		                                        string timeEditedAsString,
		                                        bool local,
		                                        Database database)
		{
			this.database = database;
			this.remoteLogID = remoteLogID;
			this.fileRemoteID = fileRemoteID;
			this.is_new = true;
			this.is_local = local;
			
			this.versionRemoteID = fileVersionID;
			this.versionName = versionName;
			this.timeEditedAsString = timeEditedAsString;
			
			this.tag = null;
			this.fileName = null;
			this.mimetype = null;
			
			insert();
		}
	
		private HistoryLogEntry.from_database(Sqlite.Statement statement,
		                                      Database database)
		{
			this.database = database;
			this.remoteLogID = statement.column_int64(COLUMN_LOG_ID);
			this.fileRemoteID = statement.column_int64(COLUMN_REMOTE_FILE_ID);
			this.is_new = statement.column_int(COLUMN_IS_NEW) == 1 ? true : false;
			this.is_local = statement.column_int(COLUMN_IS_LOCAL) == 1 ? true : false;
			
			this.fileName = statement.column_text(COLUMN_FILENAME);
			this.mimetype = statement.column_text(COLUMN_MIMETYPE);
			
			this.tag = statement.column_text(COLUMN_TAGNAME);
			
			this.versionRemoteID = statement.column_int64(COLUMN_VERSION_REMOTE_ID);
			this.versionName = statement.column_text(COLUMN_VERSION_NAME);
			this.timeEditedAsString = statement.column_text(COLUMN_VERSION_TIMEEDITED);
		}

		public static int64 find_latest_non_local(Database database)
		{
			var find_stmt = database.prepare("SELECT MAX(remoteLogID) FROM HistoryLog
				WHERE isLocal=0;");
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
				      (remoteLogID,
				       fileRemoteID,
				       isNew,
				       isLocal,
				       
				       fileName,
				       mimetype,
				       
				       tagName,
				       
				       versionRemoteID,
				       versionName,
				       timeEdited)
				VALUES(@remoteLogID,
				       @fileRemoteID,
				       @isNew,
				       @isLocal,
				       
				       @fileName,
				       @mimetype,
				       
				       @tagName,
				       
				       @versionRemoteID,
				       @versionName,
				       @timeEdited);");
			insert_stmt.bind_int64(insert_stmt.bind_parameter_index("@remoteLogID"), remoteLogID);
			insert_stmt.bind_int64(insert_stmt.bind_parameter_index("@fileRemoteID"), fileRemoteID);
			insert_stmt.bind_int(insert_stmt.bind_parameter_index("@isNew"), is_new ? 1 : 0);
			insert_stmt.bind_int(insert_stmt.bind_parameter_index("@isLocal"), is_local ? 1 : 0);
			
			if (fileName != null)
			{
				insert_stmt.bind_text(insert_stmt.bind_parameter_index("@fileName"), fileName);
			}
			else
			{
				insert_stmt.bind_null(insert_stmt.bind_parameter_index("@fileName"));
			}
			if (mimetype != null)
			{
				insert_stmt.bind_text(insert_stmt.bind_parameter_index("@mimetype"), mimetype);
			}
			else
			{
				insert_stmt.bind_null(insert_stmt.bind_parameter_index("@mimetype"));
			}
			
			if (tag != null)
			{
				insert_stmt.bind_text(insert_stmt.bind_parameter_index("@tagName"), tag);
			}
			else
			{
				insert_stmt.bind_null(insert_stmt.bind_parameter_index("@tagName"));
			}
			
			
			if (versionRemoteID != null)
			{
				insert_stmt.bind_int64(insert_stmt.bind_parameter_index("@versionRemoteID"), versionRemoteID);
			}
			else
			{
				insert_stmt.bind_null(insert_stmt.bind_parameter_index("@versionRemoteID"));
			}
			if (versionName != null)
			{
				insert_stmt.bind_text(insert_stmt.bind_parameter_index("@versionName"), versionName);
			}
			else
			{
				insert_stmt.bind_null(insert_stmt.bind_parameter_index("@versionName"));
			}
			if (timeEditedAsString != null)
			{
				insert_stmt.bind_text(insert_stmt.bind_parameter_index("@timeEdited"), timeEditedAsString);
			}
			else
			{
				insert_stmt.bind_null(insert_stmt.bind_parameter_index("@timeEditeds"));
			}
			
			int rc = insert_stmt.step();
			if (rc != Sqlite.DONE)
			{
				GLib.log("error", LogLevelFlags.LEVEL_WARNING, "ERROR IN STAMENENT: %s", database.errmsg());
			}
		}
	}
}
