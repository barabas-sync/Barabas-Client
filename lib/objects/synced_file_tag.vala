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
	public class SyncedFileTag : Object
	{
		public enum Status
		{
			NEW = 0,
			SYNCED = 1,
			DELETED = 2
		}
		
		private static const int COLUMN_FILE_ID = 0;
		private static const int COLUMN_TAG = 1;
		private static const int COLUMN_STATUS = 2;
		
		
		private Database database;
		
		public int64 file_id { get; private set; }
		public string tag { get; private set; }
		private Status _status;
		public Status status {
			get {
				return _status;
			}
			
			set {
				Sqlite.Statement statement = null;
				
				statement = database.prepare("UPDATE SyncedFileTag
					    SET status=@status
					    WHERE tag=@tag AND fileID=@fileID");
				statement.bind_int64(statement.bind_parameter_index("@fileID"), file_id);
				statement.bind_int(statement.bind_parameter_index("@status"), value);
				statement.bind_text(statement.bind_parameter_index("@tag"), tag);
				statement.step();
			
				_status = value;
			}
		}
		
		public SyncedFileTag(string tag, SyncedFile file, Status status, Database database)
		{
			this.database = database;
			this.file_id = file.ID;
			this.tag = tag;
			this.status = status;
			
			insert();
		}
		
		private SyncedFileTag.from_stmt(Sqlite.Statement stmt, Database database)
		{
			this.database = database;
			this.file_id = stmt.column_int64(COLUMN_FILE_ID);
			this.tag = stmt.column_text(COLUMN_TAG);
			this.status = (Status)stmt.column_int(COLUMN_STATUS);
		}
		
		public static Gee.Map<string, SyncedFileTag> find_tags_for_file(SyncedFile file, Database database)
		{
			Gee.Map<string, SyncedFileTag> map = new Gee.HashMap<string, SyncedFileTag>();
			
			Sqlite.Statement select = database.prepare("SELECT * FROM SyncedFileTag
			                                            WHERE fileID=@fileID;");
			
			select.bind_int64(select.bind_parameter_index("@fileID"), file.ID);
			
			while (select.step() == Sqlite.ROW)
			{
				SyncedFileTag the_tag = new SyncedFileTag.from_stmt(select, database);
				map.set(the_tag.tag, the_tag);
			}
			
			return map;
		}
		
		public void remove()
		{
			Sqlite.Statement statement = null;
				
			statement = database.prepare("DELETE FROM SyncedFileTag
				    WHERE tag=@tag AND fileID=@fileID");
			statement.bind_int64(statement.bind_parameter_index("@fileID"), file_id);
			statement.bind_text(statement.bind_parameter_index("@tag"), tag);
			statement.step();
			database = null;
		}
		
		public static Gee.List<SyncedFileTag> unsynced(Database database)
		{
			Sqlite.Statement find = database.prepare("SELECT * FROM SyncedFileTag WHERE status != @synced");
			find.bind_int(find.bind_parameter_index("@synced"), SyncedFileTag.Status.SYNCED);
			
			Gee.List<SyncedFileTag> list = new Gee.ArrayList<SyncedFileTag>();
			
			while (find.step() == Sqlite.ROW)
			{
				list.add(new SyncedFileTag.from_stmt(find, database));
			}
			return list;
		}
		
		private void insert()
		{
			Sqlite.Statement insert_stmt = database.prepare("INSERT INTO SyncedFileTag
			    (fileID, tag, status)
			    VALUES(@fileID, @tag, @status);");
			insert_stmt.bind_int64(insert_stmt.bind_parameter_index("@fileID"), file_id);
			insert_stmt.bind_text(insert_stmt.bind_parameter_index("@tag"), tag);
			insert_stmt.bind_int(insert_stmt.bind_parameter_index("@status"), (int)status);
			int rc = insert_stmt.step();
			
			if (rc == Sqlite.OK)
			{
				stdout.printf("INSERTED %s %i(OK)\n", tag, rc);
			}
			else if (rc == Sqlite.ERROR)
			{
				stdout.printf("INSERTED %s %i(ERROR) %s\n", tag, rc, database.errmsg());
			}
			stdout.printf("INSERTED %s %i\n", tag, rc);
		}
	}
}
