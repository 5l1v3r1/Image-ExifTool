#------------------------------------------------------------------------------
# File:         WriteCanonRaw.pl
#
# Description:  Routines for writing Canon RAW (CRW) files
#
# Revisions:    01/25/2005 - P. Harvey Created
#------------------------------------------------------------------------------
package Image::ExifTool::CanonRaw;

use strict;
use Image::ExifTool::Fixup;

# mappings to from RAW tagID to MakerNotes tagID
# (Note: upper two bits of RawTagID are zero)
my %mapRawTag = (
  # RawTagID => Canon TagID
    0x080b => 0x07, # CanonFirmwareVersion
    0x0810 => 0x09, # OwnerName
    0x0815 => 0x06, # CanonImageType
    0x1028 => 0x03, # (unknown if no tag name specified)
    0x1029 => 0x02, # FocalLength
    0x102a => 0x04, # CanonShotInfo
    0x102d => 0x01, # CanonCameraSettings
    0x1033 => 0x0f, # CanonCustomFunctions (only verified for 10D)
    0x1038 => 0x12, # CanonPictureInfo
    0x1039 => 0x13,
    0x1093 => 0x93,
    0x10a8 => 0xa8,
    0x10a9 => 0xa9, # WhiteBalanceTable
    0x10aa => 0xaa,
    0x10ae => 0xae, # ColorTemperature
    0x10b4 => 0xb4, # ColorSpace
    0x10b5 => 0xb5,
    0x10c0 => 0xc0,
    0x10c1 => 0xc1,
    0x180b => 0x0c, # SerialNumber
    0x1817 => 0x08, # FileNumber
    0x1834 => 0x10,
    0x183b => 0x15,
);
# translation from Rotation to Orientation values
my %mapRotation = (
    0 => 1,
    90 => 6,
    180 => 3,
    270 => 8,
);


#------------------------------------------------------------------------------
# Initialize buffers for building MakerNotes from RAW data
# Inputs: 0) ExifTool object reference
sub InitMakerNotes($)
{
    my $exifTool = shift;
    $exifTool->{MAKER_NOTE_INFO} = {
        Entries => { },     # directory entries keyed by tagID
        ValBuff => ' ',     # value data buffer
        FixupTags => { },   # flags for tags with data in value buffer
    };
}

#------------------------------------------------------------------------------
# Build maker notes from CanonRaw information
# Inputs: 0) ExifTool object reference, 1) raw tag ID, 2) reference to tagInfo
#         3) reference to value, 4) format name, 5) count
# Notes: This will build the directory in the order the tags are found in the CRW
# file, which isn't sequential (but Canon's version isn't sequential either...)
sub BuildMakerNotes($$$$$$)
{
    my ($exifTool, $rawTag, $tagInfo, $valuePt, $formName, $count) = @_;

    my $tagID = $mapRawTag{$rawTag} || return;
    $formName or warn(sprintf "No format for tag 0x%x!\n",$rawTag), return;
    # special case: ignore user comment because it gets saved in EXIF
    # (and has the same raw tagID as CanonFileDescription)
    return if $tagInfo and $$tagInfo{Name} eq 'UserComment';
    my $tagType = ($rawTag >> 8) & 0x38;
    my $format = $Image::ExifTool::Exif::formatNumber{$formName};
    my $fsiz = $Image::ExifTool::Exif::formatSize[$format];
    my $size = length($$valuePt);
    my $value;
    if ($count and $size != $count * $fsiz) {
        if ($size < $count * $fsiz) {
            warn sprintf("Value too short for raw tag 0x%x\n",$rawTag);
            return;
        }
        # shorten value appropriately
        $size = $count * $fsiz;
        $value = substr($$valuePt, 0, $size);
    } else {
        $count = $size / $fsiz;
        $value = $$valuePt;
    }
    my $offsetVal;
    my $makerInfo = $exifTool->{MAKER_NOTE_INFO};
    if ($size > 4) {
        my $len = length $makerInfo->{ValBuff};
        $offsetVal = Set32u($len);
        $makerInfo->{ValBuff} .= $value;
        # pad to an even number of bytes
        $size & 0x01 and $makerInfo->{ValBuff} .= "\0";
        # set flag indicating that this tag needs a fixup
        $makerInfo->{FixupTags}->{$tagID} = 1;
    } else {
        $offsetVal = $value;
        $size < 4 and $offsetVal .= "\0" x (4 - $size);
    }
    $makerInfo->{Entries}->{$tagID} = Set16u($tagID) . Set16u($format) .
                                      Set32u($count) . $offsetVal;
}

#------------------------------------------------------------------------------
# Finish building and save MakerNotes
# Inputs: 0) ExifTool object reference
sub SaveMakerNotes($)
{
    my $exifTool = shift;
    # save maker notes
    my $makerInfo = $exifTool->{MAKER_NOTE_INFO};
    delete $exifTool->{MAKER_NOTE_INFO};
    my $dirEntries = $makerInfo->{Entries};
    my $numEntries = scalar(keys %$dirEntries);
    my $fixup = new Image::ExifTool::Fixup;
    return unless $numEntries;
    # build the MakerNotes directory
    my $makerNotes = Set16u($numEntries);
    my $tagID;
    # write the entries in proper tag order (even though Canon doesn't do this...)
    foreach $tagID (sort { $a <=> $b } keys %$dirEntries) {
        $makerNotes .= $$dirEntries{$tagID};
        next unless $makerInfo->{FixupTags}->{$tagID};
        # add fixup for this pointer
        $fixup->AddFixup(length($makerNotes) - 4);
    }
    # save position of maker notes for pointer fixups
    $fixup->{Shift} += length($makerNotes);
    $exifTool->{MAKER_NOTE_FIXUP} = $fixup;
    $exifTool->{MAKER_NOTE_BYTE_ORDER} = GetByteOrder();
    # add value data
    $makerNotes .= $makerInfo->{ValBuff};
    # get MakerNotes tag info
    my $tagTablePtr = Image::ExifTool::GetTagTable('Image::ExifTool::Exif::Main');
    my $tagInfo = $exifTool->GetTagInfo($tagTablePtr, 0x927c);
    # save the MakerNotes
    $exifTool->FoundTag($tagInfo, $makerNotes);
    # save the garbage collection some work later
    delete $makerInfo->{Entries};
    delete $makerInfo->{ValBuff};
    delete $makerInfo->{FixupTags};
    # also generate Orientation tag since Rotation isn't transferred from RAW info
    my $rotation = $exifTool->GetValue('Rotation', 'ValueConv');
    if (defined $rotation and defined $mapRotation{$rotation}) {
        $tagInfo = $exifTool->GetTagInfo($tagTablePtr, 0x112);
        $exifTool->FoundTag($tagInfo, $mapRotation{$rotation});
    }
}

#------------------------------------------------------------------------------
# Check CanonRaw information
# Inputs: 0) ExifTool object reference, 1) tagInfo hash reference,
#         2) raw value reference
# Returns: error string or undef (and may change value) on success
sub CheckCanonRaw($$$)
{
    my ($exifTool, $tagInfo, $valPtr) = @_;
    Image::ExifTool::GenerateTagIDs($$tagInfo{Table});
    my $tagName = $$tagInfo{Name};
    if ($tagName eq 'JpgFromRaw' or $tagName eq 'ThumbnailImage') {
        unless ($$valPtr =~ /^\xff\xd8/ or $exifTool->Options('IgnoreMinorErrors')) {
            return 'Not a valid image';
        }
    } else {
        my $format = $$tagInfo{Format};
        my $count = $$tagInfo{Count};
        unless ($format) {
            my $tagType = ($$tagInfo{TagID} >> 8) & 0x38;
            $format = $crwTagFormat{$tagType};
        }
        $format and return Image::ExifTool::CheckValue($valPtr, $format, $count);
    }
    return undef;
}

#------------------------------------------------------------------------------
# Write CanonRaw information
# Inputs: 0) ExifTool object reference, 1) tag table reference,
#         2) source dirInfo reference
# Returns: undefined on error, else success message
# Notes: Increments ExifTool CHANGED flag for each tag changed This routine is
# different from all of the other write routines because Canon RAW files are
# designed well!  So it isn't necessary to buffer the data in memory before
# writing it out.  Therefore this routine doesn't return the directory data as
# the rest of the Write routines do.  Instead, it writes to the dirInfo
# Outfile on the fly --> much faster, efficient, and less demanding on memory!
sub WriteCanonRaw($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    $exifTool or return 1;    # allow dummy access to autoload this package
    my $blockStart = $dirInfo->{DirStart};
    my $blockSize = $dirInfo->{DirLen};
    my $raf = $dirInfo->{RAF} or return undef;
    my $outfile = $dirInfo->{OutFile} or return undef;
    my $outPos = $dirInfo->{OutPos} or return undef;
    my $outBase = $outPos;
    my $verbose = $exifTool->Options('Verbose');
    my ($buff, $tagInfo);

    # 4 bytes at end of block give directory position within block
    $raf->Seek($blockStart+$blockSize-4, 0) or return undef;
    $raf->Read($buff, 4) == 4 or return undef;
    my $dirOffset = Get32u(\$buff,0) + $blockStart;
    $raf->Seek($dirOffset, 0) or return undef;
    $raf->Read($buff, 2) == 2 or return undef;
    my $entries = Get16u(\$buff,0);             # get number of entries in directory
    # read the directory (10 bytes per entry)
    $raf->Read($buff, 10 * $entries) == 10 * $entries or return undef;
    my $newDir = '';

    # get hash of new information keyed by tagID
    my $newTags = $exifTool->GetNewTagInfoHash($tagTablePtr);

    # generate list of tags to add or delete (currently, we only allow JpgFromRaw
    # and ThumbnailImage, to be added or deleted from the root CanonRaw directory)
    my (@addTags, %delTag);
    if ($dirInfo->{Nesting} == 0) {
        my $tagID;
        foreach $tagID (keys %$newTags) {
            my $permanent = $newTags->{$tagID}->{Permanent};
            push(@addTags, $tagID) if defined($permanent) and not $permanent;
        }
    }

    my $index;
    for ($index=0; ; ++$index) {
        my ($pt, $tag, $size, $valuePtr, $ptr, $value);
        if ($index<$entries) {
            $pt = 10 * $index;
            $tag = Get16u(\$buff, $pt);
            $size = Get32u(\$buff, $pt+2);
            $valuePtr = Get32u(\$buff, $pt+6);
            $ptr = $valuePtr + $blockStart;        # all pointers relative to block start
        }
        # add any required new tags
        # NOTE: can't currently add tags where value is stored in directory
        if (@addTags and (not defined($tag) or $tag >= $addTags[0])) {
            my $addTag = shift @addTags;
            $tagInfo = $$newTags{$addTag};
            my $newVal = $exifTool->GetNewValues($tagInfo);
            if (defined $newVal) {
                # add new directory entry
                $newDir .= Set16u($addTag) . Set32u(length($newVal)) .
                           Set32u($outPos - $outBase);
                # write new value data
                Image::ExifTool::Write($outfile, $newVal) or return undef;
                $outPos += length($newVal);     # update current position
                $verbose > 1 and print "    + CanonRaw:$$tagInfo{Name}\n";
                ++$exifTool->{CHANGED};
            }
            # set flag to delete this tag if found later
            $delTag{$addTag} = 1;
        }
        last unless defined $tag;           # all done if no more directory entries
        return undef if $tag & 0x8000;      # top bit should not be set
        my $tagID = $tag & 0x3fff;          # get tag ID
        my $tagType = ($tag >> 8) & 0x38;   # get tag type
        my $valueInDir = ($tag & 0x4000);   # flag for value in directory

        my $tagInfo = $exifTool->GetTagInfo($tagTablePtr,$tagID);
        my $format = $crwTagFormat{$tagType};
        my ($count, $subdir);
        if ($tagInfo) {
            $subdir = $$tagInfo{SubDirectory};
            $format = $$tagInfo{Format} if $$tagInfo{Format};
            $count = $$tagInfo{Count};
        }
        if ($valueInDir) {
            $size = 8;
            $value = substr($buff, $pt+2, $size);
            # set count to 1 by default for normal values in directory
            $count = 1 if not defined $count and $format and
                          $format ne 'string' and not $subdir;
        } else {
            if ($tagType==0x28 or $tagType==0x30) {
                # this type of tag specifies a raw subdirectory
                my $name;
                $tagInfo and $name = $$tagInfo{Name};
                $name or $name = sprintf("CanonRaw_0x%.4x", $tagID);
                my %subdirInfo = (
                    DirName  => $name,
                    DataLen  => 0,
                    DirStart => $ptr,
                    DirLen   => $size,
                    Nesting  => $dirInfo->{Nesting} + 1,
                    RAF      => $raf,
                    Parent   => $dirInfo->{DirName},
                    OutFile  => $outfile,
                    OutPos   => $outPos,
                );
                my $result = $exifTool->WriteTagTable($tagTablePtr, \%subdirInfo);
                return undef unless $result;
                # set size and pointer for this new directory
                $size = $subdirInfo{OutPos} - $outPos;
                $valuePtr = $outPos - $outBase;
                $outPos = $subdirInfo{OutPos};
            } else {
                # verify that the value data is within this block
                $valuePtr + $size <= $blockSize or return undef;
                # read value from file
                $raf->Seek($ptr, 0) or return undef;
                $raf->Read($value, $size) == $size or return undef;
            }
        }
        # set count from tagInfo count if necessary
        if ($format and not $count) {
            # set count according to format and size
            my $fnum = $Image::ExifTool::Exif::formatNumber{$format};
            my $fsiz = $Image::ExifTool::Exif::formatSize[$fnum];
            $count = int($size / $fsiz);
        }
        # edit subdirectory if necessary
        if ($tagInfo) {
            if ($subdir and $$subdir{TagTable}) {
                my $name = $$tagInfo{Name};
                my $newTagTable = Image::ExifTool::GetTagTable($$subdir{TagTable});
                return undef unless $newTagTable;
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
                    $subdir = $exifTool->WriteTagTable($newTagTable, \%subdirInfo);
                    if (defined $subdir and length $subdir) {
                        if ($subdirStart) {
                            # add header before data directory
                            $value = substr($value, 0, $subdirStart) . $subdir;
                        } else {
                            $value = $subdir;
                        }
                    }
                }
            } elsif ($$newTags{$tagID}) {
                if ($delTag{$tagID}) {
                    $verbose > 1 and print "    - CanonRaw:$$tagInfo{Name}\n";
                    ++$exifTool->{CHANGED};
                    next;   # next since we already added this tag
                }
                my $oldVal;
                if ($format) {
                    $oldVal = ReadValue(\$value, 0, $format, $count, $size);
                } else {
                    $oldVal = $value;
                }
                my $newValueHash = $exifTool->GetNewValueHash($tagInfo);
                if (Image::ExifTool::IsOverwriting($newValueHash, $oldVal)) {
                    my $newVal = Image::ExifTool::GetNewValues($newValueHash);
                    my $verboseVal;
                    $verboseVal = $newVal if $verbose > 1;
                    # convert to specified format if necessary
                    if (defined $newVal and $format) {
                        $newVal = WriteValue($newVal, $format, $count);
                    }
                    if (defined $newVal) {
                        $value = $newVal;
                        ++$exifTool->{CHANGED};
                        if ($verbose > 1) {
                            my $oldStr = $exifTool->Printable($oldVal);
                            my $newStr = $exifTool->Printable($verboseVal);
                            print "    - CanonRaw:$$tagInfo{Name} = '$oldStr'\n";
                            print "    + CanonRaw:$$tagInfo{Name} = '$newStr'\n";
                        }
                    }
                }
            }
        }
        if ($valueInDir) {
            my $len = length $value;
            if ($len < 8) {
                # pad with original garbage in case it contained something useful
                $value .= substr($buff, $pt+2+8-$len, 8-$len);
            } elsif ($len > 8) {   # this shouldn't happen
                warn "Value too long! -- trucated\n";
                $value = substr($value, 0, 8);
            }
            # create new directory entry
            $newDir .= Set16u($tag) . $value;
            next;   # all done this entry
        }
        if (defined $value) {
            # don't allow value to change length unless Writable is 'resize'
            my $writable = $$tagInfo{Writable};
            my $diff = length($value) - $size;
            if ($diff) {
                if ($writable and $writable eq 'resize') {
                    $size += $diff; # allow size to change
                } elsif ($diff > 0) {
                    $value .= ("\0" x $diff);
                } else {
                    $value = substr($value, 0, $size);
                }
            }
            # pad value if necessary to align on even-byte boundary (as per CIFF spec)
            $value .= "\0" if $size & 0x01;
            $valuePtr = $outPos - $outBase;
            # write out value data
            Image::ExifTool::Write($outfile, $value) or return undef;
            $outPos += length($value);  # update current position in outfile
        }
        # create new directory entry
        $newDir .= Set16u($tag) . Set32u($size) . Set32u($valuePtr);
    }
    # add the directory counts and offset to the directory start,
    $entries = length($newDir) / 10;
    $newDir = Set16u($entries) . $newDir . Set32u($outPos - $outBase);
    # write directory data
    Image::ExifTool::Write($outfile, $newDir) or return undef;

    # update current output file position in dirInfo
    $dirInfo->{OutPos} = $outPos + length($newDir);

    return 'Success';
}

#------------------------------------------------------------------------------
# write Canon RAW (CRW) file
# Inputs: 0) ExifTool object reference, 1) output file or scalar reference
# Returns: 1 on success, 0 if this wasn't a valid CRW file,
#          or -1 if a write error occurred
sub WriteCRW($$)
{
    my ($exifTool, $outfile) = @_;
    my $verbose = $exifTool->{OPTIONS}->{Verbose};
    my $raf = $exifTool->{RAF};
    my $rtnVal = 0;
    my ($buff, $err, $sig);

    $raf->Read($buff,2) == 2 or return 0;
    SetByteOrder($buff)      or return 0;
    $raf->Read($buff,4) == 4 or return 0;
    $raf->Read($sig,8) == 8  or return 0;   # get file signature
    $sig eq 'HEAPCCDR'       or return 0;   # validate signature
    my $hlen = Get32u(\$buff, 0);   # get header length

    # write header
    $raf->Seek(0, 0)         or return 0;
    $raf->Read($buff, $hlen) == $hlen or return 0;
    Image::ExifTool::Write($outfile, $buff) or $err = 1;

    $raf->Seek(0, 2)         or return 0;   # seek to end of file
    my $filesize = $raf->Tell() or return 0;

    if ($exifTool->{DEL_GROUP}) {
        $exifTool->Error("Can't delete groups in CRW file");
        return 0;
    }

    # build directory information for main raw directory
    my %dirInfo = (
        DataLen  => 0,
        DirStart => $hlen,
        DirLen   => $filesize - $hlen,
        Nesting  => 0,
        RAF      => $raf,
        Parent   => 'CRW',
        OutFile  => $outfile,
        OutPos   => $hlen,
    );

    # process the raw directory
    my $tagTablePtr = Image::ExifTool::GetTagTable('Image::ExifTool::CanonRaw::Main');
    my $msg = $exifTool->WriteTagTable($tagTablePtr, \%dirInfo);
    if ($msg) {
        if ($err) {
            $rtnVal = -1;
        } else {
            $rtnVal = 1;    # success!
        }
    } else {
        $exifTool->Error('Error rewriting CRW file');
    }
    return $rtnVal;
}


1; # end

__END__

=head1 NAME

Image::ExifTool::WriteCanonRaw.pl - Routines for writing Canon RAW (CRW) files

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool::CanonRaw.

=head1 DESCRIPTION

This file contains routines used by ExifTool to write Canon RAW (CRW) files
and metadata.

=head1 NOTES

The CRW format is a pleasure to work with.  All pointer offsets are relative
to the start of the data for each directory.  If TIFF/EXIF had implemented
pointers in this way, it would be MUCH easier to read and write TIFF/JPEG
files, and would lead to far fewer problems with corrupted metadata.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::CanonRaw(3pm)|Image::ExifTool::CanonRaw>,
L<Image::ExifTool(3pm)|Image::ExifTool>,
L<http://owl.phy.queensu.ca/~phil/exiftool/canon_raw.html>

=cut
