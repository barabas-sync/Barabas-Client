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
	class UnsavedChangesCrawler
	{
		private Connection connection;
		private Database database;
		private bool running;
		
		private GLib.Cancellable cancel;
	
		public UnsavedChangesCrawler(Connection connection,
		                             Database database)
		{
			this.connection = connection;
			this.database = database;
			this.cancel = new GLib.Cancellable();
			this.running = false;
		}
		
		public void stop()
		{
			if (this.cancel.is_cancelled() || !running)
			{
				return;
			}
			this.cancel.cancel();
		}
			
		public async void crawl()
		{
			running = true;
			while (this.cancel.is_cancelled())
			{
				// wait until the prev crawl is over, and we can cleanly
				// restart.
							stdout.printf("WAITING\n");
				Timeout.add(50, crawl.callback);
				yield;
			}
		
			stdout.printf("CRAWLING\n");
			yield new_files();
			
			if (cancel.is_cancelled())
			{
				cancel.reset();
				return;
			}
			yield unsaved_tags();
			
			if (cancel.is_cancelled())
			{
				cancel.reset();
				return;
			}
			yield new_fileversions();
			
			if (cancel.is_cancelled())
			{
				cancel.reset();
				return;
			}
			yield crawl_filesystem();
			running = false;
			this.cancel.reset();
		}
	
		private async void new_files()
		{
			foreach (SyncedFile file in SyncedFile.unsynced(database))
			{
				connection.sync_file(file);
			}
		}
	
		private async void unsaved_tags()
		{
			int i = 0;
			const int YIELD_TIMES = 20;
			foreach (SyncedFileTag tag in SyncedFileTag.unsynced(database))
			{
				if (cancel.is_cancelled()) return;
							
				SyncedFile synced_file = SyncedFile.from_ID(database, tag.file_id);
				ICommand command = null;
				if (tag.status == SyncedFileTag.Status.NEW)
				{
					command = new NewTagCommand(synced_file, tag.tag);
				}
				else if (tag.status == SyncedFileTag.Status.DELETED)
				{
					command = new RemoveTagCommand(synced_file, tag.tag);
				}
				if (command != null)
				{
					connection.queue_command(command);
				}
				stdout.printf("TAGIT\n");
				
				i++;
				if (i == YIELD_TIMES)
				{
					i = 0;
					Idle.add(unsaved_tags.callback);
					yield;
				}
			}
		}
	
		private async void new_fileversions()
		{
			int i = 0;
			const int YIELD_TIMES = 20;
			foreach (SyncedFileVersion version in SyncedFileVersion.unsynced(database))
			{
				if (cancel.is_cancelled()) return;
			
				SyncedFile synced_file = SyncedFile.from_ID(database, version.fileID);
				LocalFile? local_file = LocalFile.from_file_id(synced_file.ID, database);
				
				if (local_file != null)
				{
					local_file.initiate_upload(synced_file, version);
				}
				else
				{
					version.deprecate();
				}
				
				i++;
				if (i == YIELD_TIMES)
				{
					i = 0;
					Idle.add(new_fileversions.callback);
					yield;
				}
			}
		}
	
		private async void crawl_filesystem()
		{
			// TODO: this is painfully slow when many files are synced.
			//       use a database iterator system.
			int i = 0;
			const int YIELD_TIMES = 5;
			foreach (LocalFile local_file in LocalFile.all(database))
			{
				if (cancel.is_cancelled()) return;
			
				if (local_file.is_modified()) {
					// TODO: this is a shameless copy paste from code from FileMonitorClient
					//       why the code is even in a separate library I don't know...
					SyncedFile? synced_file = SyncedFile.from_ID(database, local_file.syncedID);
					if (synced_file != null && synced_file.has_remote())
					{
						// See if the last version is uploaded, or uploading.
						// If so, add another version
						SyncedFileVersion last_version = synced_file.versions().last();
						if (!last_version.is_uploading_or_uploaded())
						{
							last_version.deprecate();
							synced_file.remove_version(last_version);
						}
						DateTime date = new DateTime.now_local();
						SyncedFileVersion new_version = new SyncedFileVersion(
							synced_file.ID,
							"Version from " + date.format("%Y-%m-%d %H:%M") +  " at " + GLib.Environment.get_host_name(),
							date,
							database);
						synced_file.add_version(new_version);
						local_file.initiate_upload(synced_file, new_version);
					}
					else
					{
						GLib.log("file-monitor", LogLevelFlags.LEVEL_INFO, "File ID %lli not found?", local_file.syncedID);
					}
				} else if (!local_file.exists()) {
					local_file.remove();
				}
				
				if (i == YIELD_TIMES)
				{
					i = 0;
					Idle.add(crawl_filesystem.callback);
					yield;
				}
			}
		}
	}
}
