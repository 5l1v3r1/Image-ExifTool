#------------------------------------------------------------------------------
# File:         CanonRaw.pm
#
# Description:  Definitions for Canon CRW file information
#
# Revisions:    11/25/2003 - P. Harvey Created
#               12/02/2003 - P. Harvey Completely reworked and figured out many
#                            more tags
#               01/19/2004 - P. Harvey Added CleanRaw()
#
# References:   1) http://www.cybercom.net/~dcoffin/dcraw/
#               2) http://www.wonderland.org/crw/
#               3) http://xyrion.org/ciff/CIFFspecV1R04.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::CanonRaw;

use strict;
use vars qw($VERSION $AUTOLOAD %crwTagFormat);
use Image::ExifTool qw(:DataAccess);
use Image::ExifTool::Exif;

$VERSION = '1.17';

sub WriteCRW($$);
sub ProcessCanonRaw($$$);
sub WriteCanonRaw($$$);
sub CheckCanonRaw($$$);
sub InitMakerNotes($);
sub SaveMakerNotes($);
sub BuildMakerNotes($$$$$$);

# formats for CRW tag types (($tag >> 8) & 0x38)
# Note: don't define format for undefined types
%crwTagFormat = (
    0x00 => 'int8u',
    0x08 => 'string',
    0x10 => 'int16u',
    0x18 => 'int32u',
  # 0x20 => 'undef',
  # 0x28 => 'undef',
  # 0x30 => 'undef',
);

# Canon raw file tag table
# Note: Tag ID's have upper 2 bits set to zero, since these 2 bits
# just specify the location of the information
%Image::ExifTool::CanonRaw::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonRaw,
    WRITE_PROC => \&WriteCanonRaw,
    CHECK_PROC => \&CheckCanonRaw,
    WRITABLE => 1,
    0x0000 => 'NullRecord', #3
    0x0001 => 'FreeBytes', #3
    0x0032 => { Name => 'CanonColorInfo1', Writable => 0 },
    0x0805 => [
        # this tag is found in more than one directory...
        {
            Condition => '$self->{DIR_NAME} eq "ImageDescription"',
            Name => 'CanonFileDescription',
        },
        {
            Name => 'UserComment',
        },
    ],
    0x080a => {
        Name => 'CanonRawMakeModel',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::CanonRaw::MakeModel',
        },
    },
    0x080b => 'CanonFirmwareVersion',
    0x080c => 'ComponentVersion', #3
    0x080d => 'ROMOperationMode', #3
    0x0810 => {
        Name => 'OwnerName',
        Description => "Owner's Name",
    },
    0x0815 => 'CanonImageType',
    0x0816 => 'OriginalFileName',
    0x0817 => 'ThumbnailFileName',
    0x100a => 'TargetImageType', #3
    0x1010 => { #3
        Name => 'ShutterReleaseMethod',
        PrintConv => {
            0 => 'Single Shot',
            2 => 'Continuous Shooting',
        },
    },
    0x1011 => { #3
        Name => 'ShutterReleaseTiming',
        PrintConv => {
            0 => 'Priority on shutter',
            1 => 'Priority on focus',
        },
    },
    0x1016 => 'ReleaseSetting', #3
    0x101c => 'BaseISO', #3
    0x1029 => {
        Name => 'CanonFocalLength',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::FocalLength',
        },
    },
    0x102a => {
        Name => 'CanonShotInfo',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::ShotInfo',
        },
    },
    0x102c => { Name => 'CanonColorInfo2', Writable => 0 },
    0x102d => {
        Name => 'CanonCameraSettings',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::CameraSettings',
        },
    },
    0x1031 => {
        Name => 'SensorInfo',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::CanonRaw::SensorInfo',
        },
    },
    # this tag has only be verified for the 10D in CRW files, but this
    # is the way it works for the other models with JPG files...
    0x1033 => [
        {
            Condition => '$self->{CameraModel} =~ /10D/',
            Name => 'CanonCustomFunctions10D',
            Writable => 0,
            SubDirectory => {
                TagTable => 'Image::ExifTool::CanonCustom::Functions10D',
            },
        },
        {
            Condition => '$self->{CameraModel} =~ /20D/',
            Name => 'CanonCustomFunctions20D',
            Writable => 0,
            SubDirectory => {
                TagTable => 'Image::ExifTool::CanonCustom::Functions20D',
            },
        },
        {
            # assume everything else is a D30/D60
            Name => 'CanonCustomFunctions',
            Writable => 0,
            SubDirectory => {
                TagTable => 'Image::ExifTool::CanonCustom::Functions',
            },
        },
    ],
    0x1038 => {
        Name => 'CanonPictureInfo',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::PictureInfo',
        },
    },
    0x10a9 => {
        Name => 'WhiteBalanceTable',
        Writable => 0,
        SubDirectory => {
            # this offset is necessary because the table contains short rationals
            # (4 bytes long) but the first entry is 2 bytes into the table.
            Start => '2',
            TagTable => 'Image::ExifTool::Canon::WhiteBalance',
        },
    },
    0x10b4 => {
        Name => 'ColorSpace',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
            0xffff => 'Uncalibrated',
        },
    },
    0x1803 => { #3
        Name => 'ImageFormat',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::CanonRaw::ImageFormat',
        },
    },
    0x1804 => 'RecordID', #3
    0x1806 => { #3
        Name => 'SelfTimerTime',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => '"$val sec"',
        PrintConvInv => '$val=~s/\s*sec.*//;$val',
    },
    0x1807 => {
        Name => 'TargetDistanceSetting',
        Format => 'float',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    0x180b => {
        Name => 'SerialNumber',
        Description => 'Camera Body No.',
        PrintConv => 'sprintf("%.10d",$val)',
        PrintConvInv => '$val',
    },
    0x180e => {
        Name => 'TimeStamp',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::CanonRaw::TimeStamp',
        },
    },
    0x1810 => {
        Name => 'ImageInfo',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::CanonRaw::ImageInfo',
        },
    },
    0x1813 => { #3
        Name => 'FlashInfo',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::CanonRaw::FlashInfo',
        },
    },
    0x1814 => { #3
        Name => 'MeasuredEV',
        Format => 'float',
    },
    0x1817 => {
        Name => 'FileNumber',
        Groups => { 2 => 'Image' },
        PrintConv => '$_=$val;s/(\d+)(\d{4})/$1-$2/;$_',
        PrintConvInv => '$_=$val;s/-//;$_',
    },
    0x1818 => { #3
        Name => 'ExposureInfo',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::CanonRaw::ExposureInfo',
        },
    },
    0x1835 => {
        Name => 'DecoderTable',
        Writable => 0,
    },
    0x2005 => {
        Name => 'RawData',
        Writable => 0,
        PrintConv => '\$val',
    },
    0x2007 => {
        Name => 'JpgFromRaw',
        Writable => 'resize',  # 'resize' allows this value to change size
        Permanent => 0,
        PrintConv => '\$val',
        PrintConvInv => '$val',
    },
    # the following entries are actually subdirectories --
    # 0x28 and 0x30 tag types are handled automatically by the decoding logic
    0x2804 => {
        Name => 'ImageDescription',
        Writable => 0,
    },
    0x2807 => { #3
        Name => 'CameraObject',
        Writable => 0,
    },
    0x3002 => { #3
        Name => 'ShootingRecord',
        Writable => 0,
    },
    0x3003 => { #3
        Name => 'MeasuredInfo',
        Writable => 0,
    },
    0x3004 => { #3
        Name => 'CameraSpecification',
        Writable => 0,
    },
    0x300a => { #3
        Name => 'ImageProps',
        Writable => 0,
    },
    0x300b => {
        Name => 'ExifInformation',
        Writable => 0,
    },
);

# Canon binary data blocks
%Image::ExifTool::CanonRaw::MakeModel = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'string',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # (can't specify a first entry because this isn't
    # a simple binary table with fixed offsets)
    0 => {
        Name => 'Make',
        Format => 'string[6]',  # "Canon\0"
        ValueConv => '$self->{CameraMake} = $val',
        ValueConvInv => '$val',
    },
    6 => {
        Name => 'Model',
        Format => 'string[$size-6]',
        Description => 'Camera Model Name',
        ValueConv => '$self->{CameraModel} = $val',
        ValueConvInv => '$val',
    },
);

%Image::ExifTool::CanonRaw::TimeStamp = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Time' },
    0 => {
        Name => 'DateTimeOriginal',
        Description => 'Shooting Date/Time',
        ValueConv => 'Image::ExifTool::CanonRaw::ConvertBinaryDate($val)',
        ValueConvInv => 'Image::ExifTool::CanonRaw::GetBinaryDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$val',
    },
    1 => { #3
        Name => 'TimeZoneCode',
        Format => 'int32s',
        ValueConv => '$val / 3600',
        ValueConvInv => '$val * 3600',
    },
    2 => 'TimeZoneInfo', #3
);

%Image::ExifTool::CanonRaw::ImageFormat = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => {
        Name => 'FileFormat',
        Flags => 'PrintHex',
        PrintConv => {
            0x00010000 => 'JPEG (lossy)',
            0x00010002 => 'JPEG (non-quantization)',
            0x00010003 => 'JPEG (lossy/non-quantization toggled)',
            0x00020001 => 'CRW',
        },
    },
    1 => {
        Name => 'TargetCompressionRatio',
        Format => 'float',
    },
);

%Image::ExifTool::CanonRaw::FlashInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'float',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => 'FlashGuideNumber',
    1 => 'FlashThreshold',
);

%Image::ExifTool::CanonRaw::ExposureInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'float',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => 'ExposureCompensation',
    1 => 'TvValue',
    2 => 'AvValue',
);

%Image::ExifTool::CanonRaw::SensorInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # Note: Don't make these writable because it confuses Canon decoding software
    # if these are changed
    1 => 'SensorWidth',
    2 => 'SensorHeight',
    5 => 'SensorLeftBorder', #2
    6 => 'SensorTopBorder', #2
    7 => 'SensorRightBorder', #2
    8 => 'SensorBottomBorder', #2
);

%Image::ExifTool::CanonRaw::ImageInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int32u',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # Note: Don't make these writable because it confuses Canon decoding software
    # if these are changed
    0 => 'ImageWidth', #3
    1 => 'ImageHeight', #3
    2 => { #3
        Name => 'PixelAspectRatio',
        Format => 'float',
    },
    3 => {
        Name => 'Rotation',
        Format => 'int32s',
    },
    4 => 'ComponentBitDepth', #3
    5 => 'ColorBitDepth', #3
    6 => 'ColorBW', #3
);

#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Convert binary date to string
# Inputs: 0) Long date value
sub ConvertBinaryDate($)
{
    my $time = shift;
    my @time = gmtime($time);
    return sprintf("%4d:%.2d:%.2d %.2d:%.2d:%.2d",
                   $time[5]+1900,$time[4]+1,$time[3],
                   $time[2],$time[1],$time[0]);
}

#------------------------------------------------------------------------------
# get binary date from string
# Inputs: 0) string
# Returns: Binary date or undefined on error
sub GetBinaryDate($)
{
    my $timeStr = shift;
    return undef unless $timeStr =~ /^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})/;
    my ($yr,$mon,$day,$hr,$min,$sec) = ($1,$2,$3,$4,$5,$6);
    return undef unless eval 'require Time::Local';
    return Time::Local::timegm($sec,$min,$hr,$day,$mon-1,$yr-1900);
}

#------------------------------------------------------------------------------
# Process Raw file directory
# Inputs: 0) ExifTool object reference
#         1) tag table reference, 2) directory information reference
# Returns: 1 on success
sub ProcessCanonRaw($$$)
{
    my ($exifTool, $rawTagTable, $dirInfo) = @_;
    my $blockStart = $dirInfo->{DirStart};
    my $blockSize = $dirInfo->{DirLen};
    my $raf = $dirInfo->{RAF} or return 0;
    my $buff;
    my $verbose = $exifTool->Options('Verbose');
    my $buildMakerNotes = $exifTool->Options('MakerNotes');

    # 4 bytes at end of block give directory position within block
    $raf->Seek($blockStart+$blockSize-4, 0) or return 0;
    $raf->Read($buff, 4) or return 0;
    my $dirOffset = Get32u(\$buff,0) + $blockStart;
    $raf->Seek($dirOffset, 0) or return 0;
    $raf->Read($buff, 2) or return 0;
    my $entries = Get16u(\$buff,0);         # get number of entries in directory
    # read the directory (10 bytes per entry)
    $raf->Read($buff, 10 * $entries) or return 0;
    
    $verbose and $exifTool->VerboseDir('Raw', $entries);
    my $index;
    for ($index=0; $index<$entries; ++$index) {
        my $pt = 10 * $index;
        my $tag = Get16u(\$buff, $pt);
        my $size = Get32u(\$buff, $pt+2);
        my $valuePtr = Get32u(\$buff, $pt+6);
        my $ptr = $valuePtr + $blockStart;  # all pointers relative to block start
        if ($tag & 0x8000) {
            $exifTool->Warn('Bad CRW directory entry');
            return 1;
        }
        my $tagID = $tag & 0x3fff;          # get tag ID
        my $tagType = ($tag >> 8) & 0x38;   # get tag type
        my $valueInDir = ($tag & 0x4000);   # flag for value in directory
        my $tagInfo = $exifTool->GetTagInfo($rawTagTable, $tagID);
        if (($tagType==0x28 or $tagType==0x30) and not $valueInDir) {
            # this type of tag specifies a raw subdirectory
            my $name;
            $tagInfo and $name = $$tagInfo{Name};
            $name or $name = sprintf("CanonRaw_0x%.4x", $tag);
            my %subdirInfo = (
                DirName  => $name,
                DataLen  => 0,
                DirStart => $ptr,
                DirLen   => $size,
                Nesting  => $dirInfo->{Nesting} + 1,
                RAF      => $raf,
                Parent   => $dirInfo->{DirName},
            );
            if ($verbose) {
                my $fakeInfo = { Name => $name, SubDirectory => { } };
                $exifTool->VerboseInfo($tag, $fakeInfo,
                    'Index'  => $index,
                    'Size'   => $size,
                    'Start'  => $ptr,
                );
            }
            $exifTool->ProcessTagTable($rawTagTable, \%subdirInfo);
            next;
        }
        my ($valueDataPos, $count, $subdir);
        my $format = $crwTagFormat{$tagType};
        if ($tagInfo) {
            $subdir = $$tagInfo{SubDirectory};
            $format = $$tagInfo{Format} if $$tagInfo{Format};
            $count = $$tagInfo{Count};
        }
        # get value data
        my $value;
        if ($valueInDir) {  # is the value data in the directory?
            # this type of tag stores the value in the 'size' and 'ptr' fields
            $valueDataPos = $dirOffset + $valuePtr;
            $size = 8;
            $value = substr($buff, $pt+2, $size);
            # set count to 1 by default for normal values in directory
            $count = 1 if not defined $count and $format and
                          $format ne 'string' and not $subdir;
        } else {
            $valueDataPos = $ptr;
            if ($size <= 512 or ($verbose > 2 and $size <= 65536)
                or ($tagInfo and ($$tagInfo{SubDirectory} 
                or grep(/^$$tagInfo{Name}$/i, $exifTool->GetRequestedTags()) )))
            {
                # read value if size is small or specifically requested
                # or if this is a SubDirectory
                unless ($raf->Seek($ptr, 0) and $raf->Read($value, $size)) {
                    $exifTool->Warn(sprintf("Error reading %d bytes from 0x%x",$size,$ptr));
                    next;
                }
            } else {
                $value = "Binary data $size bytes";
                if ($tagInfo) {
                    if ($exifTool->Options('Binary')) {
                        # read the value anyway
                        unless ($raf->Seek($ptr, 0) and $raf->Read($value, $size)) {
                            $exifTool->Warn(sprintf("Error reading %d bytes from 0x%x",$size,$ptr));
                            next;
                        }
                    }
                    # force this to be a binary (scalar reference)
                    $$tagInfo{PrintConv} = '\$val';
                }
                $size = length $value;
                undef $format;
            }
        }
        # set count from tagInfo count if necessary
        if ($format and not $count) {
            # set count according to format and size
            my $fnum = $Image::ExifTool::Exif::formatNumber{$format};
            my $fsiz = $Image::ExifTool::Exif::formatSize[$fnum];
            $count = int($size / $fsiz);
        }
        if ($verbose) {
            my $val = $value;
            $format and $val = ReadValue(\$val, 0, $format, $count, $size);
            $exifTool->VerboseInfo($tag, $tagInfo,
                'Table'  => $rawTagTable,
                'Index'  => $index,
                'Value'  => $val,
                'DataPt' => \$value,
                'Addr'   => $blockStart + $valueDataPos,
                'Size'   => $size,
                'Format' => $format,
                'Count'  => $count,
            );
        }
        if ($buildMakerNotes) {
            # build maker notes information if requested
            BuildMakerNotes($exifTool, $tagID, $tagInfo, \$value, $format, $count);
        }
        next unless defined $tagInfo;

        if ($subdir) {
            my $name = $$tagInfo{Name};
            my $newTagTable;
            if ($$subdir{TagTable}) {
                $newTagTable = Image::ExifTool::GetTagTable($$subdir{TagTable});
                unless ($newTagTable) {
                    warn "Unknown tag table $$subdir{TagTable}\n";
                    next;
                }
            } else {
                warn "Must specify TagTable for SubDirectory $name\n";
                next;
            }
            my $subdirStart = 0;
            #### eval Start ()
            $subdirStart = eval $$subdir{Start} if $$subdir{Start};
            my $dirData = \$value;
            my %subdirInfo = (
                Name     => $name,
                DataPt   => $dirData,
                DataLen  => $size,
                DirStart => $subdirStart,
                DirLen   => $size - $subdirStart,
                Nesting  => $dirInfo->{Nesting} + 1,
                RAF      => $raf,
                Parent   => $dirInfo->{DirName},
            );
            #### eval Validate ($dirData, $subdirStart, $size)
            if (defined $$subdir{Validate} and not eval $$subdir{Validate}) {
                $exifTool->Warn("Invalid $name data");
            } else {
                $exifTool->ProcessTagTable($newTagTable, \%subdirInfo, $$subdir{ProcessProc});
            }
        } else {
            # convert to specified format if necessary
            $format and $value = ReadValue(\$value, 0, $format, $count, $size);
            # check for valid JpgFromRaw image
            if ($$tagInfo{Name} ne 'JpgFromRaw' or
                $value =~ /^(Binary|\xff\xd8)/ or
                $exifTool->Options('IgnoreMinorErrors'))
            {
                $exifTool->FoundTag($tagInfo, $value);
            } else {
                $exifTool->Warn('JpgFromRaw is not a valid image');   
            }
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# get information from raw file
# Inputs: 0) ExifTool object reference
# Returns: 1 if this was a valid Canon RAW file
sub CrwInfo($$)
{
    my $exifTool = shift;
    my ($buff, $sig);
    my $raf = $exifTool->{RAF};
    my $buildMakerNotes = $exifTool->Options('MakerNotes');
    
    $raf->Read($buff,2) == 2      or return 0; 
    SetByteOrder($buff)           or return 0;
    $raf->Read($buff,4) == 4      or return 0;
    $raf->Read($sig,8) == 8       or return 0;  # get file signature
    $sig eq 'HEAPCCDR'            or return 0;  # validate signature
    my $hlen = Get32u(\$buff, 0);
    
    $raf->Seek(0, 2)              or return 0;  # seek to end of file
    my $filesize = $raf->Tell()   or return 0;

    # initialize maker note data if building maker notes
    $buildMakerNotes and InitMakerNotes($exifTool);

    $exifTool->FoundTag('FileType', 'Canon RAW');  # set file type
    
    # build directory information for main raw directory
    my %dirInfo = (
        DataLen  => 0,
        DirStart => $hlen,
        DirLen   => $filesize - $hlen,
        Nesting  => 0,
        RAF      => $raf,
        Parent   => 'CRW',
    );
    
    # process the raw directory
    my $rawTagTable = Image::ExifTool::GetTagTable('Image::ExifTool::CanonRaw::Main');
    $exifTool->ProcessTagTable($rawTagTable, \%dirInfo);

    # finish building maker notes if necessary
    $buildMakerNotes and SaveMakerNotes($exifTool);

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::CanonRaw - Definitions for Canon RAW file meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
meta information from Canon RAW files.  These files are written directly by
some Canon cameras, and contain meta information similar to that found in
the EXIF Canon maker notes.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item http://www.cybercom.net/~dcoffin/dcraw/

=item http://www.wonderland.org/crw/

=item http://xyrion.org/ciff/

=item Lots of testing with my own camera... ;)

=back

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut

