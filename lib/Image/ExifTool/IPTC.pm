#------------------------------------------------------------------------------
# File:         IPTC.pm
#
# Description:  Definitions for IPTC information
#
# Revisions:    Jan. 08/03 - P. Harvey Created
#               Feb. 05/04 - P. Harvey Added support for records other than 2
#
# References:   1) http://brilliantlabs.com/docs/IIMV4.1.pdf
#               2) http://www.hugsan.com/EXIFutils/Features/EXIF_Fields/IPTC/iptc.html
#------------------------------------------------------------------------------

package Image::ExifTool::IPTC;

use strict;
use vars qw($VERSION $AUTOLOAD);

$VERSION = '1.04';

sub ProcessIPTC($$$);
sub WriteIPTC($$$);
sub CheckIPTC($$$);

my %fileFormat = (
    0 => 'No ObjectData',
    1 => 'IPTC-NAA Digital Newsphoto Parameter Record',
    2 => 'IPTC7901 Recommended Message Format',
    3 => 'Tagged Image File Format (Adobe/Aldus Image data)',
    4 => 'Illustrator (Adobe Graphics data)',
    5 => 'AppleSingle (Apple Computer Inc)',
    6 => 'NAA 89-3 (ANPA 1312)',
    7 => 'MacBinary II',
    8 => 'IPTC Unstructured Character Oriented File Format (UCOFF)',
    9 => 'United Press International ANPA 1312 variant',
    10 => 'United Press International Down-Load Message',
    11 => 'JPEG File Interchange (JFIF)',
    12 => 'Photo-CD Image-Pac (Eastman Kodak)',
    13 => 'Bit Mapped Graphics File [.BMP] (Microsoft)',
    14 => 'Digital Audio File [.WAV] (Microsoft & Creative Labs)',
    15 => 'Audio plus Moving Video [.AVI] (Microsoft)',
    16 => 'PC DOS/Windows Executable Files [.COM][.EXE]',
    17 => 'Compressed Binary File [.ZIP] (PKWare Inc)',
    18 => 'Audio Interchange File Format AIFF (Apple Computer Inc)',
    19 => 'RIFF Wave (Microsoft Corporation)',
    20 => 'Freehand (Macromedia/Aldus)',
    21 => 'Hypertext Markup Language [.HTML] (The Internet Society)',
    22 => 'MPEG 2 Audio Layer 2 (Musicom), ISO/IEC',
    23 => 'MPEG 2 Audio Layer 3, ISO/IEC',
    24 => 'Portable Document File [.PDF] Adobe',
    25 => 'News Industry Text Format (NITF)',
    26 => 'Tape Archive [.TAR]',
    27 => 'Tidningarnas Telegrambyra NITF version (TTNITF DTD)',
    28 => 'Ritzaus Bureau NITF version (RBNITF DTD)',
    29 => 'Corel Draw [.CDR]',
);

# main IPTC tag table
# Note: ALL entries in main IPTC table (except PROCESS_PROC) must be SubDirectory
# entries, each specifying a TagTable.
%Image::ExifTool::IPTC::Main = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessIPTC,
    WRITE_PROC => \&WriteIPTC,
    1 => {
        Name => 'IPTCEnvelope',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::EnvelopeRecord',
        },
    },
    2 => {
        Name => 'IPTCApplication',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::ApplicationRecord',
        },
    },
    3 => {
        Name => 'IPTCNewsPhoto',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::NewsPhoto',
        },
    },
    7 => {
        Name => 'IPTCPreObjectData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::PreObjectData',
        },
    },
    8 => {
        Name => 'IPTCObjectData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::ObjectData',
        },
    },
    9 => {
        Name => 'IPTCPostObjectData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::PostObjectData',
        },
    },
);

# Record 1 -- EnvelopeRecord
%Image::ExifTool::IPTC::EnvelopeRecord = (
    GROUPS => { 2 => 'Other' },
    WRITE_PROC => \&WriteIPTC,
    CHECK_PROC => \&CheckIPTC,
    WRITABLE => 1,
    0 => {
        Name => 'EnvelopeRecordVersion',
        Format => 'binary[2]',
    },
    5 => {
        Name => 'Destination',
        Flags => 'List',
        Groups => { 2 => 'Location' },
        Format => 'string[0,1024]',
    },
    20 => {
        Name => 'FileFormat',
        Groups => { 2 => 'Image' },
        Format => 'binary[2]',
        PrintConv => \%fileFormat,
    },
    22 => {
        Name => 'FileVersion',
        Groups => { 2 => 'Image' },
        Format => 'binary[2]',
    },
    30 => {
        Name => 'ServiceIdentifier',
        Format => 'string[0,10]',
    },
    40 => {
        Name => 'EnvelopeNumber',
        Format => 'digits[8]',
    },
    50 => {
        Name => 'ProductID',
        Flags => 'List',
        Format => 'string[0,32]',
    },
    60 => {
        Name => 'EnvelopePriority',
        Format => 'digits[1]',
    },
    70 => {
        Name => 'DateSent',
        Groups => { 2 => 'Time' },
        Format => 'digits[8]',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
    },
    80 => {
        Name => 'TimeSent',
        Groups => { 2 => 'Time' },
        Format => 'string[11]',
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcTime($val)',
    },
    90 => {
        Name => 'CodedCharacterSet',
        Format => 'string[0,32]',
    },
    100 => {
        Name => 'UniqueObjectName',
        Format => 'string[14,80]',
    },
    120 => {
        Name => 'ARMIdentifier',
        Format => 'binary[2]',
    },
    122 => {
        Name => 'ARMVersion',
        Format => 'binary[2]',
    },
);

# Record 2 -- ApplicationRecord
%Image::ExifTool::IPTC::ApplicationRecord = (
    GROUPS => { 2 => 'Other' },
    WRITE_PROC => \&WriteIPTC,
    CHECK_PROC => \&CheckIPTC,
    WRITABLE => 1,
    0 => {
        Name => 'ApplicationRecordVersion',
        Format => 'binary[2]',
    },
    3 => {
        Name => 'ObjectTypeReference',
        Format => 'string[3,67]',
    },
    4 => {
        Name => 'ObjectAttributeReference',
        Flags => 'List',
        Format => 'string[4,68]',
    },
    5 => {
        Name => 'ObjectName',
        Format => 'string[0,64]',
    },
    7 => {
        Name => 'EditStatus',
        Format => 'string[0,64]',
    },
    8 => {
        Name => 'EditorialUpdate',
        Format => 'digits[2]',
    },
    10 => {
        Name => 'Urgency',
        Format => 'digits[1]',
    },
    12 => {
        Name => 'SubjectReference',
        Flags => 'List',
        Format => 'string[13,236]',
    },
    15 => {
        Name => 'Category',
        Format => 'string[0,3]',
    },
    20 => {
        Name => 'SupplementalCategories',
        Flags => 'List',
        Format => 'string[0,32]',
    },
    22 => {
        Name => 'FixtureIdentifier',
        Format => 'string[0,32]',
    },
    25 => {
        Name => 'Keywords',
        Flags => 'List',
        Format => 'string[0,64]',
    },
    26 => {
        Name => 'ContentLocationCode',
        Flags => 'List',
        Groups => { 2 => 'Location' },
        Format => 'string[3]',
    },
    27 => {
        Name => 'ContentLocationName',
        Flags => 'List',
        Groups => { 2 => 'Location' },
        Format => 'string[0,64]',
    },
    30 => {
        Name => 'ReleaseDate',
        Groups => { 2 => 'Time' },
        Format => 'digits[8]',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
    },
    35 => {
        Name => 'ReleaseTime',
        Groups => { 2 => 'Time' },
        Format => 'digits[11]',
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcTime($val)',
    },
    37 => {
        Name => 'ExpirationDate',
        Groups => { 2 => 'Time' },
        Format => 'digits[8]',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
    },
    38 => {
        Name => 'ExpirationTime',
        Groups => { 2 => 'Time' },
        Format => 'digits[11]',
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcTime($val)',
    },
    40 => {
        Name => 'SpecialInstructions',
        Format => 'string[0,256]',
    },
    42 => {
        Name => 'ActionAdvised',
        Format => 'digits[2]',
        PrintConv => {
            '' => '',
            '01' => 'Object Kill',
            '02' => 'Object Replace',
            '03' => 'Ojbect Append',
            '04' => 'Object Reference',
        },
    },
    45 => {
        Name => 'ReferenceService',
        Flags => 'List',
        Format => 'string[0,10]',
    },
    47 => {
        Name => 'ReferenceDate',
        Flags => 'List',
        Format => 'digits[8]',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
    },
    50 => {
        Name => 'ReferenceNumber',
        Flags => 'List',
        Format => 'digits[8]',
    },
    55 => {
        Name => 'DateCreated',
        Format => 'digits[8]',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
    },
    60 => {
        Name => 'TimeCreated',
        Groups => { 2 => 'Time' },
        Format => 'digits[11]',
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcTime($val)',
    },
    62 => {
        Name => 'DigitalCreationDate',
        Groups => { 2 => 'Time' },
        Format => 'digits[8]',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
    },
    63 => {
        Name => 'DigitalCreationTime',
        Groups => { 2 => 'Time' },
        Format => 'digits[11]',
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcTime($val)',
    },
    65 => {
        Name => 'OriginatingProgram',
        Format => 'string[0,32]',
    },
    70 => {
        Name => 'ProgramVersion',
        Format => 'string[0,10]',
    },
    75 => {
        Name => 'ObjectCycle',
        Format => 'string[1]',
        PrintConv => {
            'a' => 'Morning',
            'p' => 'Evening',
            'b' => 'Both Morning and Evening',
        },
    },
    80 => {
        Name => 'By-line',
        Flags => 'List',
        Format => 'string[0,32]',
        Groups => { 2 => 'Author' },
    },
    85 => {
        Name => 'By-lineTitle',
        Flags => 'List',
        Format => 'string[0,32]',
        Groups => { 2 => 'Author' },
    },
    90 => {
        Name => 'City',
        Format => 'string[0,32]',
        Groups => { 2 => 'Location' },
    },
    92 => {
        Name => 'Sub-location',
        Format => 'string[0,32]',
        Groups => { 2 => 'Location' },
    },
    95 => {
        Name => 'Province-State',
        Format => 'string[0,32]',
        Groups => { 2 => 'Location' },
    },
    100 => {
        Name => 'Country-PrimaryLocationCode',
        Format => 'string[3]',
        Groups => { 2 => 'Location' },
    },
    101 => {
        Name => 'Country-PrimaryLocationName',
        Format => 'string[0,64]',
        Groups => { 2 => 'Location' },
    },
    103 => {
        Name => 'OriginalTransmissionReference',
        Format => 'string[0,32]',
    },
    105 => {
        Name => 'Headline',
        Format => 'string[0,256]',
    },
    110 => {
        Name => 'Credit',
        Groups => { 2 => 'Author' },
        Format => 'string[0,32]',
    },
    115 => {
        Name => 'Source',
        Groups => { 2 => 'Author' },
        Format => 'string[0,32]',
    },
    116 => {
        Name => 'CopyrightNotice',
        Groups => { 2 => 'Author' },
        Format => 'string[0,128]',
    },
    118 => {
        Name => 'Contact',
        Flags => 'List',
        Groups => { 2 => 'Author' },
        Format => 'string[0,128]',
    },
    120 => {
        Name => 'Caption-Abstract',
        Format => 'string[0,2000]',
    },
    122 => {
        Name => 'Writer-Editor',
        Flags => 'List',
        Groups => { 2 => 'Author' },
        Format => 'string[0,32]',
    },
    125 => {
        Name => 'RasterizedCaption',
        Format => 'string[7360]',
        PrintConv => '\$val',
        PrintConvInv => '$val',
    },
    130 => {
        Name => 'ImageType',
        Groups => { 2 => 'Image' },
        Format => 'string[2]',
    },
    131 => {
        Name => 'ImageOrientation',
        Groups => { 2 => 'Image' },
        Format => 'string[1]',
        PrintConv => {
            P => 'Portrait',
            L => 'Landscape',
            S => 'Square',
        },
    },
    135 => {
        Name => 'LanguageIdentifier',
        Format => 'string[2,3]',
    },
    150 => {
        Name => 'AudioType',
        Format => 'string[2]',
        PrintConv => {
            '1A' => 'Mono Actuality',
            '2A' => 'Stereo Actuality',
            '1C' => 'Mono Question and Answer Session',
            '2C' => 'Stereo Question and Answer Session',
            '1M' => 'Mono Music',
            '2M' => 'Stereo Music',
            '1Q' => 'Mono Response to a Question',
            '2Q' => 'Stereo Response to a Question',
            '1R' => 'Mono Raw Sound',
            '2R' => 'Stereo Raw Sound',
            '1S' => 'Mono Scener',
            '2S' => 'Stereo Scener',
            '0T' => 'Text Only',
            '1V' => 'Mono Voicer',
            '2V' => 'Stereo Voicer',
            '1W' => 'Mono Wrap',
            '2W' => 'Stereo Wrap',
        },
    },
    151 => {
        Name => 'AudioSamplingRate',
        Format => 'digits[6]',
    },
    152 => {
        Name => 'AudioSamplingResolution',
        Format => 'digits[2]',
    },
    153 => {
        Name => 'AudioDuration',
        Format => 'digits[6]',
    },
    154 => {
        Name => 'AudioOutcue',
        Format => 'string[0,64]',
    },
    200 => {
        Name => 'ObjectPreviewFileFormat',
        Groups => { 2 => 'Image' },
        Format => 'binary[2]',
        PrintConv => \%fileFormat,
    },
    201 => {
        Name => 'ObjectPreviewFileVersion',
        Groups => { 2 => 'Image' },
        Format => 'binary[2]',
    },
    202 => {
        Name => 'ObjectPreviewData',
        Groups => { 2 => 'Image' },
        Format => 'string[0,256000]',
        PrintConv => '\$val',
        PrintConvInv => '$val',
    },
);

# Record 3 -- News photo (ref 2)
%Image::ExifTool::IPTC::NewsPhoto = (
    GROUPS => { 2 => 'Image' },
    WRITE_PROC => \&WriteIPTC,
    CHECK_PROC => \&CheckIPTC,
    WRITABLE => 1,
    0 => {
        Name => 'NewsPhotoVersion',
        Format => 'binary[2]',
    },
    10 => {
        Name => 'IPTCPictureNumber',
        Format => 'string[0,16]',
    },
    20 => {
        Name => 'IPTCImageWidth',
        Format => 'binary[2]',
    },
    30 => {
        Name => 'IPTCImageHeight',
        Format => 'binary[2]',
    },
    40 => {
        Name => 'IPTCPixelWidth',
        Format => 'binary[2]',
    },
    50 => {
        Name => 'IPTCPixelHeight',
        Format => 'binary[2]',
    },
    55 => {
        Name => 'SupplementalType',
        Format => 'binary[1]',
        PrintConv => {
            0 => 'Main Image',
            1 => 'Reduced Resolution Image',
            2 => 'Logo',
            3 => 'Rasterized Caption',
        },
    },
    60 => {
        Name => 'ColorRepresentation',
        Format => 'binary[1]',
    },
    64 => {
        Name => 'InterchangeColorSpace',
        Format => 'binary[1]',
        PrintConv => {
            1 => 'X,Y,Z CIE',
            2 => 'RGB SMPTE',
            3 => 'Y,U,V (K) (D65)',
            4 => 'RGB Device Dependent',
            5 => 'CMY (K) Device Dependent',
            6 => 'Lab (K) CIE',
            7 => 'YCbCr',
            8 => 'sRGB',
        },
    },
    65 => {
        Name => 'ColorSequence',
        Format => 'binary[1]',
    },
    84 => {
        Name => 'NumIndexEntries',
        Format => 'binary[2]',
    },
    86 => {
        Name => 'IPTCBitsPerSample',
        Format => 'binary[1]',
    },
    90 => {
        Name => 'SampleStructure',
        Format => 'binary[1]',
        PrintConv => {
            0 => 'OrthogonalConstangSampling',
            1 => 'Orthogonal4-2-2Sampling',
            2 => 'CompressionDependent',
        },
    },
    100 => {
        Name => 'ScanningDirection',
        Format => 'binary[1]',
        PrintConv => {
            0 => 'L-R, Top-Bottom',
            1 => 'R-L, Top-Bottom',
            2 => 'L-R, Bottom-Top',
            3 => 'R-L, Bottom-Top',
            4 => 'Top-Bottom, L-R',
            5 => 'Bottom-Top, L-R',
            6 => 'Top-Bottom, R-L',
            7 => 'Bottom-Top, R-L',
        },
    },
    102 => {
        Name => 'IPTCImageRotation',
        Format => 'binary[1]',
        PrintConv => {
            0 => 0,
            1 => 90,
            2 => 180,
            3 => 270,
        },
    },
    110 => {
        Name => 'DataCompressionMethod',
        Format => 'binary[1]',
    },
    120 => {
        Name => 'QuantizationMethod',
        Format => 'binary[1]',
        PrintConv => {
            0 => 'Linear Reflectance/Transmittance',
            1 => 'Linear Density',
            2 => 'IPTC Ref B',
            3 => 'Linear Dot Percent',
            4 => 'AP Domestic Analogue',
            5 => 'Compression Method Specific',
            6 => 'Color Space Specific',
            7 => 'Gamma Compensated',
        },
    },
    125 => {
        Name => 'EndPoints',
        Format => 'binary[1]',
    },
    130 => {
        Name => 'ExcursionTolerance',
        Format => 'binary[1]',
        PrintConv => {
            0 => 'Not Allowed',
            1 => 'Allowed',
        },
    },
    135 => {
        Name => 'BitsPerComponent',
        Format => 'binary[1]',
    },
);

# Record 7 -- Pre-object Data
%Image::ExifTool::IPTC::PreObjectData = (
    10 => {
        Name => 'SizeMode',
        Format => 'binary[1]',
        PrintConv => {
            0 => 'Size Not Known',
            1 => 'Size Known',
        },
    },
    20 => {
        Name => 'MaxSubfileSize',
        Format => 'binary[4]',
    },
    90 => {
        Name => 'ObjectSizeAnnounced',
        Format => 'binary[4]',
    },
    95 => {
        Name => 'MaximumObjectSize',
        Format => 'binary[4]',
    },
);

# Record 8 -- ObjectData
%Image::ExifTool::IPTC::ObjectData = (
    10 => {
        Name => 'SubFile',
        Flags => 'List',
        PrintConv => '\$val',
        PrintConvInv => '$val',
    },
);

# Record 9 -- PostObjectData
%Image::ExifTool::IPTC::PostObjectData = (
    10 => {
        Name => 'ConfirmedObjectSize',
        Format => 'binary[4]',
    },
);

# Composite IPTC tags
%Image::ExifTool::IPTC::Composite = (
    # Note: the following 2 composite tags are duplicated in Image::ExifTool::XMP
    # (only the first loaded definition is used)
    DateTimeCreated => {
        Description => 'Date/Time Created',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'DateCreated',
            1 => 'TimeCreated',
        },
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    # set the original date/time from DateTimeCreated if not set already
    DateTimeOriginal => {
        Condition => 'not defined($oldVal)',
        Description => 'Shooting Date/Time',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'DateTimeCreated',
        },
        ValueConv => '$val[0]',
        PrintConv => '$valPrint[0]',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags(\%Image::ExifTool::IPTC::Composite);


#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# get IPTC info
# Inputs: 0) ExifTool object reference, 1) reference to tag table
#         2) dirInfo reference
# Returns: 1 on success, 0 otherwise
sub ProcessIPTC($$$)
{
    my ($exifTool, $tagTablePtr, $dirInfo) = @_;
    my $dataPt = $dirInfo->{DataPt};
    my $pos = $dirInfo->{DirStart} || 0;
    my $dirLen = $dirInfo->{DirLen} || 0;
    my $dirEnd = $pos + $dirLen;
    my $verbose = $exifTool->Options('Verbose');
    my $success = 0;

    $verbose and $dirInfo and $exifTool->VerboseDir('IPTC', 0, $$dirInfo{DirLen});
    while ($pos + 5 <= $dirEnd) {
        my $buff = substr($$dataPt, $pos, 5);
        my ($id, $rec, $tag, $len) = unpack("CCCn", $buff);
        unless ($id == 0x1c) {
            unless ($id) {
                # scan the rest of the data an give warning unless all zeros
                # (iMatch pads the IPTC block with nulls for some reason)
                my $remaining = substr($$dataPt, $pos, $dirEnd - $pos);
                last unless $remaining =~ /[^\0]/;
            }
            $exifTool->Warn(sprintf('Bad IPTC data tag (marker 0x%x)',$id));
            last;
        }
        my $tableInfo = $tagTablePtr->{$rec};
        unless ($tableInfo) {
            $verbose and $exifTool->Warn("Unrecognized IPTC record: $rec");
            last;   # stop now because we're probably reading garbage
        }
        my $tableName = $tableInfo->{SubDirectory}->{TagTable};
        unless ($tableName) {
            $exifTool->Warn("No table for IPTC record $rec!");
            last;   # this shouldn't happen
        }
        $pos += 5;      # step to after field header
        # handle extended IPTC entry if necessary
        if ($len & 0x8000) {
            my $n = $len & 0x7fff; # get num bytes in length field
            if ($pos + $n > $dirEnd or $n > 8) {
                $verbose and print "Invalid extended IPTC entry (tag $tag)\n";
                $success = 0;
                last;
            }
            # determine length (a big-endian, variable sized binary number)
            for ($len = 0; $n; ++$pos, --$n) {
                $len = $len * 256 + ord(substr($$dataPt, $pos, 1));
            }
        }
        if ($pos + $len > $dirEnd) {
            $verbose and print "Invalid IPTC entry (tag $tag, len $len)\n";
            $success = 0;
            last;
        }
        my $val = substr($$dataPt, $pos, $len);
        my $recordPtr = Image::ExifTool::GetTagTable($tableName);
        my $tagInfo = $exifTool->GetTagInfo($recordPtr, $tag);
        $verbose and $exifTool->VerboseInfo($tag, $tagInfo,
            'Table'  => $tagTablePtr,
            'Value'  => $val,
            'DataPt' => $dataPt,
            'Size'   => $len,
            'Start'  => $pos,
            'Extra'  => ', ' . $tableInfo->{Name} . ' record',
        );
        if ($tagInfo) {
            my $format = $tagInfo->{Format};
            if (ref $tagInfo eq 'HASH' and $format) {
                if ($format =~ /^binary/) {
                    $val = 0;
                    my $i;
                    for ($i=0; $i<$len; ++$i) {
                        $val = $val * 256 + ord(substr($$dataPt, $pos+$i, 1));
                    }
                } elsif ($format !~ /^(string|digits)/) {
                    warn("Invalid IPTC format: $format");
                }
            }
        } else {
            $tagInfo = sprintf("IPTC_%d", $tag);
        }
        $exifTool->FoundTag($tagInfo, $val);
        $success = 1;

        $pos += $len;   # increment to next field
    }
    return $success;
}

1; # end


__END__

=head1 NAME

Image::ExifTool::IPTC - Definitions for IPTC meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
IPTC (International Press Telecommunications Council) meta information in
image files.

=head1 AUTHOR

Copyright 2003-2005, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item http://brilliantlabs.com/docs/IIMV4.1.pdf

=item http://www.hugsan.com/EXIFutils/Features/EXIF_Fields/IPTC/iptc.html

=back

=head1 SEE ALSO

L<Image::ExifTool|Image::ExifTool>

=cut
