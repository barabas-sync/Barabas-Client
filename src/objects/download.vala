/**
    This file is part of Barabas DBUS Client.

	Copyright (C) 2011 Nathan Samson
 
    Barabas DBUS Client is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Barabas DBUS Client is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Barabas DBUS Client.  If not, see <http://www.gnu.org/licenses/>.
*/

namespace Barabas.DBus.Server
{
	[DBus (name = "be.ac.ua.comp.Barabas.Download")]
	public class Download : AResource
	{
		Client.RequestDownloadCommand download_command;
	
		public Download(Client.RequestDownloadCommand command)
		{
			download_command = command;
			command.download_started.connect(download_started);
			command.download_progress.connect(download_progress);
			command.download_stopped.connect(download_stopped);
		}
		
		public void start_request()
		{
			stdout.printf("?.???\n");
			start_requested(download_command);
		}
		
		public signal void started();
		public signal void progress(int64 progress, int64 total);
		public signal void stopped();
		
		private void download_started()
		{
			started();
		}
		
		private void download_progress(int64 the_progress, int64 total)
		{
			progress(the_progress, total);
		}
		
		private void download_stopped()
		{
			stopped();
		}
		
		internal signal void start_requested(Client.RequestDownloadCommand command);
		
		protected override void do_register(string path, DBusConnection connection)
		{
			connection.register_object(path, this);
		}
	}
}
