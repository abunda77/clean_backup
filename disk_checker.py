#!/usr/bin/env python3
import os
import sys
from pathlib import Path

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
    file_count = 0
    folder_count = 0
    
    try:
        for dirpath, dirnames, filenames in os.walk(folder_path):
            folder_count += len(dirnames)
            for filename in filenames:
                file_path = os.path.join(dirpath, filename)
                try:
                    if os.path.exists(file_path):
                        total_size += os.path.getsize(file_path)
                        file_count += 1
                except (OSError, IOError):
                    continue
    except PermissionError:
        print(f"❌ Permission denied: {folder_path}")
        return None, None, None
    
    return total_size, file_count, folder_count

def get_disk_usage(path):
    """Get disk usage statistics for the given path"""
    try:
        statvfs = os.statvfs(path)
        total = statvfs.f_frsize * statvfs.f_blocks
        free = statvfs.f_frsize * statvfs.f_available
        used = total - free
        return total, used, free
    except:
        return None, None, None

def display_results(folder_path, folder_size, file_count, folder_count):
    """Display formatted results"""
    print("\n" + "="*60)
    print(f"📁 Folder Analysis: {folder_path}")
    print("="*60)
    
    if folder_size is None:
        print("❌ Could not analyze folder (permission denied or not found)")
        return
    
    print(f"📊 Total Size:     {format_bytes(folder_size)}")
    print(f"📄 Files:          {file_count:,}")
    print(f"📂 Subfolders:     {folder_count:,}")
    
    # Disk usage information
    total, used, free = get_disk_usage(folder_path)
    if total:
        print(f"\n💾 Disk Usage (partition containing this folder):")
        print(f"   Total:          {format_bytes(total)}")
        print(f"   Used:           {format_bytes(used)} ({used/total*100:.1f}%)")
        print(f"   Free:           {format_bytes(free)} ({free/total*100:.1f}%)")
        
        if folder_size > 0:
            percentage = (folder_size / total) * 100
            print(f"   This folder:    {percentage:.2f}% of total disk")

def main():
    print("🔍 Interactive Disk Space Checker")
    print("="*40)
    
    while True:
        try:
            folder_path = input("\n📁 Enter folder path (or 'q' to quit): ").strip()
            
            if folder_path.lower() in ['q', 'quit', 'exit']:
                print("👋 Goodbye!")
                break
            
            if not folder_path:
                folder_path = os.getcwd()
                print(f"Using current directory: {folder_path}")
            
            # Expand user home directory if needed
            folder_path = os.path.expanduser(folder_path)
            
            if not os.path.exists(folder_path):
                print(f"❌ Path does not exist: {folder_path}")
                continue
            
            if not os.path.isdir(folder_path):
                print(f"❌ Path is not a directory: {folder_path}")
                continue
            
            print(f"🔄 Analyzing folder: {folder_path}")
            print("Please wait...")
            
            folder_size, file_count, folder_count = get_folder_size(folder_path)
            display_results(folder_path, folder_size, file_count, folder_count)
            
        except KeyboardInterrupt:
            print("\n\n👋 Interrupted by user. Goodbye!")
            break
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()