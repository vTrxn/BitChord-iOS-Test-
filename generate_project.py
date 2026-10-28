import os
import hashlib

def gen_id(name):
    # Generates a 24-char hex Xcode object ID
    return hashlib.md5(name.encode('utf-8')).hexdigest()[:24].upper()

project_dir = os.path.dirname(os.path.abspath(__file__))
bitchord_dir = os.path.join(project_dir, "BitChord")

swift_files = []
for root, dirs, files in os.walk(bitchord_dir):
    for f in files:
        if f.endswith('.swift'):
            rel_path = os.path.relpath(os.path.join(root, f), project_dir).replace('\\', '/')
            swift_files.append((f, rel_path))

# PBXBuildFile section
build_files = []
for fname, fpath in swift_files:
    fid = gen_id("file_" + fpath)
    bfid = gen_id("build_" + fpath)
    build_files.append(f"\t\t{bfid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {fname} */; }};")

# PBXFileReference section
file_refs = []
for fname, fpath in swift_files:
    fid = gen_id("file_" + fpath)
    file_refs.append(f"\t\t{fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{os.path.basename(fpath)}\"; sourceTree = \"<group>\"; }};")

# Add Info.plist and Assets
info_fid = gen_id("file_Info.plist")
assets_fid = gen_id("file_Assets.xcassets")
assets_bfid = gen_id("build_Assets.xcassets")
file_refs.append(f"\t\t{info_fid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
file_refs.append(f"\t\t{assets_fid} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
build_files.append(f"\t\t{assets_bfid} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_fid} /* Assets.xcassets */; }};")

# Product file
app_fid = gen_id("file_BitChord.app")
file_refs.append(f"\t\t{app_fid} /* BitChord.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = BitChord.app; sourceTree = BUILT_PRODUCTS_DIR; }};")

# Sources build phase
sources_build_phase_id = gen_id("phase_sources")
sources_entries = "\n".join([f"\t\t\t\t{gen_id('build_' + fpath)} /* {fname} in Sources */," for fname, fpath in swift_files])

# Resources build phase
resources_build_phase_id = gen_id("phase_resources")
resources_entries = f"\t\t\t\t{assets_bfid} /* Assets.xcassets in Resources */,"

# Frameworks build phase
frameworks_build_phase_id = gen_id("phase_frameworks")

# Groups
def build_group_tree():
    groups = {}
    
    # Root group
    main_group_id = gen_id("group_main")
    products_group_id = gen_id("group_products")
    
    # Collect folders
    folders = {}
    for fname, fpath in swift_files:
        parts = fpath.split('/')[:-1] # e.g. ['BitChord', 'App']
        curr = ""
        for p in parts:
            prev = curr
            curr = f"{curr}/{p}" if curr else p
            if curr not in folders:
                folders[curr] = {"name": p, "children": [], "path": p}
            if prev and curr not in folders[prev]["children"]:
                folders[prev]["children"].append(curr)

    # Put files into their folders
    for fname, fpath in swift_files:
        folder = '/'.join(fpath.split('/')[:-1])
        folders[folder]["children"].append(fpath)
        
    # Ensure BitChord/Resources exists
    if "BitChord" not in folders:
        folders["BitChord"] = {"name": "BitChord", "children": [], "path": "BitChord"}
    if "BitChord/Resources" not in folders:
        folders["BitChord/Resources"] = {"name": "Resources", "children": [], "path": "Resources"}
        if "BitChord/Resources" not in folders["BitChord"]["children"]:
            folders["BitChord"]["children"].append("BitChord/Resources")

    # Add Info.plist and Assets to BitChord/Resources
    folders["BitChord/Resources"]["children"].append("Info.plist")
    folders["BitChord/Resources"]["children"].append("Assets.xcassets")
    
    group_lines = []
    
    # Products group
    group_lines.append(f"""\t\t{products_group_id} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_fid} /* BitChord.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};""")

    # Sub groups
    for folder_path, data in folders.items():
        gid = gen_id("group_" + folder_path)
        children_lines = []
        for c in data["children"]:
            if c in folders:
                cid = gen_id("group_" + c)
                cname = folders[c]["name"]
                children_lines.append(f"\t\t\t\t{cid} /* {cname} */,")
            elif c == "Info.plist":
                children_lines.append(f"\t\t\t\t{info_fid} /* Info.plist */,")
            elif c == "Assets.xcassets":
                children_lines.append(f"\t\t\t\t{assets_fid} /* Assets.xcassets */,")
            else:
                cid = gen_id("file_" + c)
                cname = os.path.basename(c)
                children_lines.append(f"\t\t\t\t{cid} /* {cname} */,")
        
        children_str = "\n".join(children_lines)
        group_lines.append(f"""\t\t{gid} /* {data['name']} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children_str}
\t\t\t);
\t\t\tpath = "{data['name']}";
\t\t\tsourceTree = "<group>";
\t\t}};""")

    # Main group
    top_bitchord_gid = gen_id("group_BitChord")
    group_lines.append(f"""\t\t{main_group_id} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{top_bitchord_gid} /* BitChord */,
\t\t\t\t{products_group_id} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};""")
    
    return main_group_id, "\n".join(group_lines)

main_group_id, groups_content = build_group_tree()

target_id = gen_id("target_BitChord")
project_id = gen_id("project_BitChord")
config_debug_target = gen_id("config_debug_target")
config_release_target = gen_id("config_release_target")
config_list_target = gen_id("config_list_target")
config_debug_proj = gen_id("config_debug_proj")
config_release_proj = gen_id("config_release_proj")
config_list_proj = gen_id("config_list_proj")

pbxproj_content = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{frameworks_build_phase_id} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{groups_content}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target_id} /* BitChord */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {config_list_target} /* Build configuration list for PBXNativeTarget "BitChord" */;
\t\t\tbuildPhases = (
\t\t\t\t{sources_build_phase_id} /* Sources */,
\t\t\t\t{frameworks_build_phase_id} /* Frameworks */,
\t\t\t\t{resources_build_phase_id} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = BitChord;
\t\t\tproductName = BitChord;
\t\t\tproductReference = {app_fid} /* BitChord.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{project_id} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{target_id} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {config_list_proj} /* Build configuration list for PBXProject "BitChord" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group_id};
\t\t\tproductRefGroup = {gen_id("group_products")} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{target_id} /* BitChord */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{resources_build_phase_id} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{resources_entries}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{sources_build_phase_id} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{sources_entries}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{config_debug_proj} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{config_release_proj} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = "wholemodule";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{config_debug_target} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = BitChord/Resources/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.bitchord.ios;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{config_release_target} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = BitChord/Resources/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.bitchord.ios;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{config_list_proj} /* Build configuration list for PBXProject "BitChord" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{config_debug_proj} /* Debug */,
\t\t\t\t{config_release_proj} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{config_list_target} /* Build configuration list for PBXNativeTarget "BitChord" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{config_debug_target} /* Debug */,
\t\t\t\t{config_release_target} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = {project_id} /* Project object */;
}}
"""

out_dir = os.path.join(project_dir, "BitChord.xcodeproj")
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "project.pbxproj")
with open(out_path, "w", encoding="utf-8") as f:
    f.write(pbxproj_content)

print(f"Generated {out_path} with {len(swift_files)} Swift source files.")
