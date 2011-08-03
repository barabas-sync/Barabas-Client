
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
	public abstract class AResource : Object
	{
		private int dbus_ref_count;
		protected DBusConnection dbus_connection;
		protected string dbus_path;
	
		protected abstract void do_register(string path, DBusConnection connection);
	
		internal virtual void publish(string path, DBusConnection connection)
		{
			this.dbus_connection = connection;
			this.dbus_path = path;
			do_register(path, connection);
		}
		
		internal virtual void unpublish()
		{
		}
	
		internal void refcount()
		{
			dbus_ref_count++;
		}
	
		public void free()
		{
			dbus_ref_count--;
		
			if (dbus_ref_count == 0)
			{
				unpublish();
				//on_freed_all();
			}
		}
		//internal signal void on_freed_all();
	}
}
