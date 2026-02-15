# Software Module

<cite>
**Referenced Files in This Document**
- [Software.psm1](file://modules/Software.psm1)
- [PatchMyPC.ini](file://configs/PatchMyPC.ini)
- [winget_packages.json](file://configs/winget_packages.json)
- [Logging.psm1](file://modules/Logging.psm1)
- [README.md](file://README.md)
</cite>

## Update Summary
**Changes Made**
- Enhanced Remote Desktop Tools section to document RustDesk and AnyDesk installation capabilities
- Added detailed documentation for Install-RustDesk and Install-AnyDesk functions
- Updated Remote Desktop Tools integration with comprehensive fallback mechanisms
- Expanded desktop shortcut creation documentation for remote desktop tools
- Added practical examples for remote desktop tool installations

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Dependency Analysis](#dependency-analysis)
7. [Performance Considerations](#performance-considerations)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Conclusion](#conclusion)

## Introduction
The Software module is a comprehensive third-party software installation and management system integrated into the System Optimizer toolkit. It provides unified access to multiple package managers and installation strategies, enabling automated software deployment with fallback mechanisms and user-friendly interfaces.

The module integrates three primary installation systems:
- **PatchMyPC Integration**: Automated software updater with pre-selected and self-select configurations
- **Winget Package Manager**: Windows-native package manager with preset categories (essential, runtimes, developer, gaming)
- **Chocolatey Package Manager**: Enterprise-grade package management with GUI support

Additionally, it includes specialized remote desktop tool installations (RustDesk, AnyDesk) with automatic desktop shortcut creation and comprehensive fallback strategies.

## Project Structure
The Software module follows a modular architecture with clear separation of concerns:

```mermaid
graph TB
subgraph "Software Module"
SM[Software.psm1]
PM[PatchMyPC Integration]
WG[Winget Integration]
CH[Chocolatey Integration]
RD[Remote Desktop Tools]
SC[Shortcut Creation]
end
subgraph "Configuration Files"
PPI[PatchMyPC.ini]
WPJ[winget_packages.json]
end
subgraph "Supporting Modules"
LG[Logging.psm1]
CM[Core Module]
end
SM --> PM
SM --> WG
SM --> CH
SM --> RD
SM --> SC
PM --> PPI
WG --> WPJ
SM --> LG
SM --> CM
```

**Diagram sources**
- [Software.psm1](file://modules/Software.psm1#L1-L131)
- [PatchMyPC.ini](file://configs/PatchMyPC.ini#L1-L376)
- [winget_packages.json](file://configs/winget_packages.json#L1-L108)

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L1-L131)
- [README.md](file://README.md#L42-L46)

## Core Components

### PatchMyPC Integration System
The PatchMyPC integration provides two distinct installation modes:

**Pre-Selected Mode**: Downloads a pre-configured configuration file containing approved software selections, eliminating user decision-making while ensuring compatibility.

**Self-Select Mode**: Provides interactive selection interface allowing users to choose from available software options.

Both modes utilize a structured configuration system that defines which applications to install and their installation parameters.

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L48-L108)
- [PatchMyPC.ini](file://configs/PatchMyPC.ini#L1-L376)

### Winget Package Manager Integration
The Winget integration offers four preset categories designed for different user needs:

- **Essential Apps**: Core productivity software including browsers, compression tools, media players, and Adobe Reader
- **Runtimes**: Comprehensive runtime libraries (.NET, Visual C++, Java, DirectX)
- **Developer Tools**: Development environment essentials (PowerShell, Git, VS Code, Python)
- **Gaming Apps**: Gaming platform and related software (Steam, Epic Games, Discord)

Each preset is carefully curated to provide optimal functionality while maintaining compatibility across different Windows versions.

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L209-L303)
- [winget_packages.json](file://configs/winget_packages.json#L82-L106)

### Chocolatey Package Manager Support
Chocolatey integration provides enterprise-grade package management with three key capabilities:

- **Chocolatey Installation**: Automated installation of the Chocolatey package manager itself
- **Essential Packages**: Streamlined installation of commonly needed software
- **Chocolatey GUI**: Installation of the graphical user interface for package management

Chocolatey serves as a robust fallback system when Winget installations encounter issues or when enterprise environments require additional package management capabilities.

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L455-L504)
- [Software.psm1](file://modules/Software.psm1#L889-L903)

### Remote Desktop Tool Management
Specialized installation functions for popular remote desktop solutions:

- **RustDesk**: Open-source alternative with automatic shortcut creation
- **AnyDesk**: Commercial remote desktop solution with comprehensive fallback support

Both tools include intelligent installation strategies that attempt Winget installation first, fall back to Chocolatey if needed, and finally provide manual download links when automated methods fail.

**Updated** Enhanced remote desktop tool integration with comprehensive installation strategies and desktop shortcut creation

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L506-L585)
- [Software.psm1](file://modules/Software.psm1#L587-L666)
- [Software.psm1](file://modules/Software.psm1#L628-L708)

## Architecture Overview

```mermaid
sequenceDiagram
participant User as User Interface
participant SM as Software Module
participant PM as PatchMyPC Engine
participant WG as Winget Manager
participant CH as Chocolatey Manager
participant RT as Remote Tools
User->>SM : Start-PatchMyPC()
SM->>PM : Download Pre-Selected Config
PM->>PM : Launch PatchMyPC.exe
PM->>User : Display Software Selection
User->>PM : Make Selection
PM->>PM : Process Selection
PM->>SM : Set-AdobeReaderAsDefault()
User->>SM : Install-WingetPreset()
SM->>WG : Check Winget Availability
WG->>WG : Validate Package IDs
WG->>User : Install Packages
WG->>SM : Set-AdobeReaderAsDefault() (if essential)
User->>SM : Install-RustDesk()
SM->>WG : Try Winget First
alt Winget Success
WG->>RT : Install RustDesk
else Winget Failure
SM->>CH : Install Chocolatey
CH->>RT : Install RustDesk
end
SM->>RT : Create Desktop Shortcut
```

**Diagram sources**
- [Software.psm1](file://modules/Software.psm1#L5-L131)
- [Software.psm1](file://modules/Software.psm1#L209-L303)
- [Software.psm1](file://modules/Software.psm1#L506-L585)

## Detailed Component Analysis

### Start-PatchMyPC Function
The main entry point provides a comprehensive software installation interface with 13 distinct options covering all supported installation methods.

```mermaid
flowchart TD
Start([Start-PatchMyPC]) --> Menu[Display Main Menu]
Menu --> Choice{User Choice}
Choice --> |1| PreSelect[Pre-Selected Mode]
Choice --> |2| SelfSelect[Self-Select Mode]
Choice --> |3-6| WingetPresets[Winget Presets]
Choice --> |7| SecurityTools[Security Tools]
Choice --> |8| WingetGUI[Winget GUI]
Choice --> |9| InstallChoco[Install Chocolatey]
Choice --> |10| ChocoEssentials[Chocolatey Essentials]
Choice --> |11| ChocoGUI[Chocolatey GUI]
Choice --> |12| InstallRustDesk[RustDesk Installation]
Choice --> |13| InstallAnyDesk[AnyDesk Installation]
PreSelect --> PMDownload[Download PatchMyPC.exe]
PMDownload --> PMConfig[Download Pre-Selected Config]
PMConfig --> PMRun[Launch PatchMyPC]
PMRun --> SetDefault[Set Adobe Reader Default]
WingetPresets --> InstallWinget[Install-WingetPreset]
InstallRustDesk --> RSInstall[Install-RustDesk]
InstallAnyDesk --> ADInstall[Install-AnyDesk]
SetDefault --> Menu
InstallWinget --> Menu
RSInstall --> Menu
ADInstall --> Menu
```

**Diagram sources**
- [Software.psm1](file://modules/Software.psm1#L5-L131)

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L5-L131)

### Install-WingetPreset Function
Provides categorized software installation with comprehensive error handling and user feedback.

```mermaid
flowchart TD
Start([Install-WingetPreset]) --> CheckWinget{Check Winget}
CheckWinget --> |Not Available| OpenStore[Open Microsoft Store]
CheckWinget --> |Available| LoadPreset[Load Preset Packages]
LoadPreset --> IteratePkg[Iterate Through Packages]
IteratePkg --> InstallPkg[Install Package]
InstallPkg --> CheckResult{Installation Success?}
CheckResult --> |Success| LogSuccess[Log Success]
CheckResult --> |Failure| LogWarning[Log Warning]
LogSuccess --> NextPkg[Next Package]
LogWarning --> NextPkg
NextPkg --> MorePkgs{More Packages?}
MorePkgs --> |Yes| IteratePkg
MorePkgs --> |No| Complete[Complete Installation]
Complete --> CheckAdobe{Preset is Essential?}
CheckAdobe --> |Yes| SetDefault[Set Adobe Reader Default]
CheckAdobe --> |No| End([End])
SetDefault --> End
```

**Diagram sources**
- [Software.psm1](file://modules/Software.psm1#L209-L303)

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L209-L303)

### Install-RustDesk Function
Comprehensive remote desktop installation with multi-source fallback support.

```mermaid
flowchart TD
Start([Install-RustDesk]) --> CheckWinget{Check Winget}
CheckWinget --> |Available| TryWinget[Try Winget Install]
CheckWinget --> |Not Available| TryChocolatey[Try Chocolatey]
TryWinget --> WingetSuccess{Winget Success?}
WingetSuccess --> |Yes| CreateShortcut[Create Desktop Shortcut]
WingetSuccess --> |No| TryChocolatey
TryChocolatey --> CheckChocolatey{Chocolatey Available?}
CheckChocolatey --> |No| InstallChocolatey[Install Chocolatey]
CheckChocolatey --> |Yes| TryChocolateyInstall[Install via Chocolatey]
InstallChocolatey --> RefreshPath[Refresh PATH Environment]
RefreshPath --> TryChocolateyInstall
TryChocolateyInstall --> ChocolateySuccess{Chocolatey Success?}
ChocolateySuccess --> |Yes| CreateShortcut
ChocolateySuccess --> |No| ManualDownload[Provide Manual Download Link]
ManualDownload --> End([End])
CreateShortcut --> End
```

**Diagram sources**
- [Software.psm1](file://modules/Software.psm1#L548-L627)

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L548-L627)

### Install-AnyDesk Function
Enterprise-grade remote desktop installation with identical fallback strategy to RustDesk.

```mermaid
flowchart TD
Start([Install-AnyDesk]) --> CheckWinget{Check Winget}
CheckWinget --> |Available| TryWinget[Try Winget Install]
CheckWinget --> |Not Available| TryChocolatey[Try Chocolatey]
TryWinget --> WingetSuccess{Winget Success?}
WingetSuccess --> |Yes| CreateShortcut[Create Desktop Shortcut]
WingetSuccess --> |No| TryChocolatey
TryChocolatey --> CheckChocolatey{Chocolatey Available?}
CheckChocolatey --> |No| InstallChocolatey[Install Chocolatey]
CheckChocolatey --> |Yes| TryChocolateyInstall[Install via Chocolatey]
InstallChocolatey --> RefreshPath[Refresh PATH Environment]
RefreshPath --> TryChocolateyInstall
TryChocolateyInstall --> ChocolateySuccess{Chocolatey Success?}
ChocolateySuccess --> |Yes| CreateShortcut
ChocolateySuccess --> |No| ManualDownload[Provide Manual Download Link]
ManualDownload --> End([End])
CreateShortcut --> End
```

**Diagram sources**
- [Software.psm1](file://modules/Software.psm1#L629-L708)

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L629-L708)

### Multi-Source Installation Strategy
The system implements a sophisticated fallback mechanism that maximizes installation success rates:

```mermaid
flowchart TD
Start([Installation Request]) --> TryWinget[Try Winget First]
TryWinget --> WingetSuccess{Winget Success?}
WingetSuccess --> |Yes| Success[Installation Complete]
WingetSuccess --> |No| TryChocolatey[Try Chocolatey]
TryChocolatey --> ChocolateySuccess{Chocolatey Success?}
ChocolateySuccess --> |Yes| Success
ChocolateySuccess --> |No| ManualDownload[Manual Download]
ManualDownload --> ProvideLink[Provide Manual Installation Link]
ProvideLink --> End([End])
Success --> CreateShortcut[Create Desktop Shortcut]
CreateShortcut --> End
```

**Diagram sources**
- [Software.psm1](file://modules/Software.psm1#L506-L585)
- [Software.psm1](file://modules/Software.psm1#L587-L666)

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L506-L585)
- [Software.psm1](file://modules/Software.psm1#L587-L666)

### Desktop Shortcut Creation System
Automatically creates desktop shortcuts for installed applications using a comprehensive search strategy:

```mermaid
flowchart TD
Start([Create Desktop Shortcut]) --> SearchPaths[Search Common Paths]
SearchPaths --> FoundExe{Executable Found?}
FoundExe --> |Yes| CreateShortcut[Create Shortcut]
FoundExe --> |No| BroadSearch[Broad System Search]
BroadSearch --> FoundExe2{Executable Found?}
FoundExe2 --> |Yes| CreateShortcut
FoundExe2 --> |No| LogWarning[Log Warning]
CreateShortcut --> SetProperties[Set Properties]
SetProperties --> SaveShortcut[Save to Desktop]
SaveShortcut --> Success[Installation Complete]
LogWarning --> End([End])
Success --> End
```

**Diagram sources**
- [Software.psm1](file://modules/Software.psm1#L668-L721)
- [Software.psm1](file://modules/Software.psm1#L723-L773)

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L668-L721)
- [Software.psm1](file://modules/Software.psm1#L723-L773)

## Dependency Analysis

```mermaid
graph TB
subgraph "External Dependencies"
PM[PatchMyPC.exe]
WG[Winget CLI]
CH[Chocolatey CLI]
RT[RustDesk/AnyDesk]
end
subgraph "Internal Dependencies"
LG[Logging.psm1]
FS[File System]
REG[Windows Registry]
COM[COM Objects]
end
subgraph "Configuration Dependencies"
PPI[PatchMyPC.ini]
WPJ[winget_packages.json]
end
SM[Software Module] --> PM
SM --> WG
SM --> CH
SM --> RT
SM --> LG
SM --> FS
SM --> REG
SM --> COM
PM --> PPI
WG --> WPJ
```

**Diagram sources**
- [Software.psm1](file://modules/Software.psm1#L5-L131)
- [PatchMyPC.ini](file://configs/PatchMyPC.ini#L1-L376)
- [winget_packages.json](file://configs/winget_packages.json#L1-L108)

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L1-L921)
- [Logging.psm1](file://modules/Logging.psm1#L1-L284)

## Performance Considerations
The Software module is designed for efficient operation with several built-in optimizations:

- **Parallel Processing**: Individual package installations are processed sequentially to maintain stability and provide clear feedback
- **Resource Management**: Temporary files are cleaned up automatically after successful installations
- **Network Efficiency**: Configuration files are cached locally to minimize repeated downloads
- **Error Containment**: Failed installations don't block subsequent package processing
- **Memory Usage**: Minimal memory footprint with efficient string handling and object disposal

## Troubleshooting Guide

### Common Installation Issues

**Winget Not Found**
- **Symptom**: Winget installation fails with "command not found"
- **Solution**: Install Microsoft Store App Installer or manually install Winget
- **Detection**: Automatic check with Microsoft Store redirection

**PatchMyPC Configuration Issues**
- **Symptom**: Pre-selected mode fails to load configuration
- **Solution**: Verify internet connectivity and retry download
- **Detection**: Network timeout handling with fallback mechanisms

**Chocolatey Installation Failures**
- **Symptom**: Chocolatey installation fails due to execution policy
- **Solution**: Run with administrative privileges and bypass execution policy
- **Detection**: Automatic execution policy adjustment

**Remote Desktop Installation Problems**
- **Symptom**: RustDesk/AnyDesk installation fails
- **Solution**: Try alternative package manager or manual download
- **Detection**: Multi-stage fallback with comprehensive error logging

**Desktop Shortcut Creation Failures**
- **Symptom**: Shortcuts not created despite successful installations
- **Solution**: Manually create shortcuts or check desktop permissions
- **Detection**: Comprehensive file system search with fallback strategies

**Section sources**
- [Software.psm1](file://modules/Software.psm1#L212-L219)
- [Software.psm1](file://modules/Software.psm1#L458-L475)
- [Software.psm1](file://modules/Software.psm1#L694-L701)

## Conclusion
The Software module represents a comprehensive solution for third-party software management on Windows systems. Its multi-source approach ensures high installation success rates through intelligent fallback mechanisms, while its modular design provides flexibility for different deployment scenarios.

Key strengths include:
- **Reliability**: Multi-layered fallback strategies maximize installation success
- **Usability**: Intuitive interfaces for both automated and manual installation modes
- **Flexibility**: Support for multiple package managers and installation methods
- **Integration**: Seamless integration with external configuration systems
- **Automation**: Comprehensive automation with minimal user intervention

The module successfully addresses the challenge of managing diverse software ecosystems while maintaining system stability and user control. Its design principles provide a foundation for future enhancements and additional package manager integrations.

**Updated** Enhanced with comprehensive remote desktop tool installation capabilities, providing users with reliable access to both open-source and commercial remote desktop solutions through intelligent fallback mechanisms and automated desktop shortcut creation.