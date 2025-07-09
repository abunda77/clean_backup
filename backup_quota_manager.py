#!/usr/bin/env python3
import os
import shutil
from pathlib import Path
from datetime import datetime
 
# ANSI color codes for styled output
RESET = "\033[0m"
BOLD = "\033[1m"
RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
BLUE = "\033[34m"
CYAN = "\033[36m"
MAGENTA = "\033[35m"

def format_bytes(bytes_value):
    """Convert bytes to human readable format"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_value < 1024.0:
            return f"{bytes_value:.2f} {unit}"
        bytes_value /= 1024.0
    return f"{bytes_value:.2f} PB"

def get_folder_size(folder_path):
    """Calculate total size of a folder recursively"""
    total_size = 0
    try:
        for dirpath, dirnames, filenames in os.walk(folder_path):
            for filename in filenames:
                file_path = os.path.join(dirpath, filename)
                try:
                    if os.path.exists(file_path):
                        total_size += os.path.getsize(file_path)
                except (OSError, IOError):
                    continue
    except PermissionError:
        return None
    return total_size

def get_folder_info(folder_path):
    """Get folder modification time and size"""
    try:
        stat = os.stat(folder_path)
        mod_time = datetime.fromtimestamp(stat.st_mtime)
        size = get_folder_size(folder_path)
        return mod_time, size
    except:
        return None, None

def scan_backup_folders(backup_path):
    """Scan and list all folders in backup directory with their sizes"""
    if not os.path.exists(backup_path):
        print(f"{RED}❌ Backup path does not exist: {backup_path}{RESET}")
        return []
    
    if not os.path.isdir(backup_path):
        print(f"{RED}❌ Path is not a directory: {backup_path}{RESET}")
        return []
    
    folders = []
    try:
        for item in os.listdir(backup_path):
            item_path = os.path.join(backup_path, item)
            if os.path.isdir(item_path):
                mod_time, size = get_folder_info(item_path)
                if size is not None:
                    folders.append({
                        'name': item,
                        'path': item_path,
                        'size': size,
                        'mod_time': mod_time
                    })
    except PermissionError:
        print(f"{RED}❌ Permission denied accessing: {backup_path}{RESET}")
        return []
    
    # Sort by size (largest first)
    folders.sort(key=lambda x: x['size'], reverse=True)
    return folders

def display_folders(folders, backup_path):
    """Display folders with their information"""
    total_size = sum(folder['size'] for folder in folders)
    
    print(f"\n{BOLD}{CYAN}📁 Backup Directory:{RESET} {backup_path}")
    print("="*80)
    print(f"{MAGENTA}📊 Total folders:{RESET} {len(folders)}")
    print(f"{MAGENTA}💾 Total size:{RESET} {format_bytes(total_size)}")
    print("="*80)
    
    if not folders:
        print("📂 No folders found in backup directory")
        return
    
    print(f"{'No.':<4} {'Folder Name':<30} {'Size':<12} {'Modified':<20}")
    print("-" * 80)
    
    for i, folder in enumerate(folders, 1):
        mod_time_str = folder['mod_time'].strftime("%Y-%m-%d %H:%M") if folder['mod_time'] else "Unknown"
        print(f"{i:<4} {folder['name']:<30} {format_bytes(folder['size']):<12} {mod_time_str:<20}")

def delete_folder(folder_path, folder_name):
    """Safely delete a folder"""
    try:
        print(f"{YELLOW}🗑️  Deleting folder:{RESET} {folder_name}")
        shutil.rmtree(folder_path)
        print(f"{GREEN}✅ Successfully deleted:{RESET} {folder_name}")
        return True
    except PermissionError:
        print(f"{RED}❌ Permission denied: Cannot delete {folder_name}{RESET}")
        return False
    except Exception as e:
        print(f"{RED}❌ Error deleting {folder_name}: {e}{RESET}")
        return False

def get_disk_usage(path):
    """Get disk usage statistics"""
    try:
        statvfs = os.statvfs(path)
        total = statvfs.f_frsize * statvfs.f_blocks
        free = statvfs.f_frsize * statvfs.f_available
        used = total - free
        return total, used, free
    except:
        return None, None, None

def display_disk_usage(backup_path, total_backup_size):
    """Display disk usage information"""
    total, used, free = get_disk_usage(backup_path)
    if total:
        print(f"\n{BOLD}{BLUE}💾 Disk Usage Information:{RESET}")
        print(f"   Total disk space: {format_bytes(total)}")
        print(f"   Used space:       {format_bytes(used)} ({used/total*100:.1f}%)")
        print(f"   Free space:       {format_bytes(free)} ({free/total*100:.1f}%)")
        if total_backup_size > 0:
            backup_percentage = (total_backup_size / total) * 100
            print(f"   Backup folders:   {format_bytes(total_backup_size)} ({backup_percentage:.2f}% of disk)")

def main():
    backup_path = "/home/clp/backups"
    
    print(f"{BOLD}{BLUE}🔍 Backup Quota Manager{RESET}")
    print("="*50)
    print(f"{BOLD}{CYAN}📁 Monitoring:{RESET} {backup_path}")
    
    while True:
        print("\n" + "="*50)
        folders = scan_backup_folders(backup_path)
        
        if not folders:
            print("No folders to manage. Exiting.")
            break
        
        display_folders(folders, backup_path)
        
        total_backup_size = sum(folder['size'] for folder in folders)
        display_disk_usage(backup_path, total_backup_size)
        
        print(f"\n{BOLD}{YELLOW}🛠️  Options:{RESET}")
        print("   1-{}: Delete specific folder by number".format(len(folders)))
        print("   a: Delete all folders")
        print("   r: Refresh/rescan")
        print("   q: Quit")
        
        try:
            choice = input("\n🔧 Enter your choice: ").strip().lower()
            
            if choice == 'q':
                print("👋 Goodbye!")
                break
            elif choice == 'r':
                print("🔄 Refreshing...")
                continue
            elif choice == 'a':
                confirm = input(f"⚠️  Are you sure you want to delete ALL {len(folders)} folders? (yes/no): ").strip().lower()
                if confirm in ['yes', 'y']:
                    deleted_count = 0
                    for folder in folders:
                        if delete_folder(folder['path'], folder['name']):
                            deleted_count += 1
                    print(f"✅ Deleted {deleted_count} out of {len(folders)} folders")
                else:
                    print("❌ Operation cancelled")
            elif choice.isdigit():
                folder_num = int(choice)
                if 1 <= folder_num <= len(folders):
                    folder = folders[folder_num - 1]
                    confirm = input(f"⚠️  Delete '{folder['name']}' ({format_bytes(folder['size'])})? (yes/no): ").strip().lower()
                    if confirm in ['yes', 'y']:
                        delete_folder(folder['path'], folder['name'])
                    else:
                        print("❌ Operation cancelled")
                else:
                    print(f"❌ Invalid number. Please enter 1-{len(folders)}")
            else:
                print("❌ Invalid choice. Please try again.")
                
        except KeyboardInterrupt:
            print("\n\n👋 Interrupted by user. Goodbye!")
            break
        except ValueError:
            print("❌ Invalid input. Please enter a valid option.")
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()