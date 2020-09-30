﻿;{
; * ResourceManager.pbi
; Version: 0.0.1
; Author: Herwin Bozet
; 
; This modules stores and handles all the indexed resources for the game.
;}

;- Compiler Directives

CompilerIf #PB_Compiler_IsMainFile: CompilerError "Unable to compile an include file !": CompilerEndIf
EnableExplicit

UsePNGImageDecoder()


;- Module

DeclareModule Resources
	Declare.b Init()
	Declare.b Start()
	Declare.b Finish(CleanMemory.b = #True)
	
	Declare.q ReadIndexFiles(RealParentFolder$, Folder$)
	
	Declare.b Update()
	Declare.b UpdateAll()
	
	Declare.i HasResource(ResourceId$, ResourceType.i)
	Declare.i HasTexture(ResourceId$)
	Declare.i HasMaterial(ResourceId$)
	Declare.i HasMesh(ResourceId$)
	Declare.i HasEntity(ResourceId$)
	Declare.i HasCamera(ResourceId$)
	
	Declare.i GetTexture(ResourceId$)
	Declare.i GetMaterial(ResourceId$)
	Declare.i GetMesh(ResourceId$)
	Declare.i GetEntity(ResourceId$)
	Declare.i GetCamera(ResourceId$)
	
	Declare.b SetTexture(ResourceId$, Resource.i, Overwrite.b = #False, AutoCleanMemory.b = #True)
	Declare.b SetMaterial(ResourceId$, Resource.i, Overwrite.b = #False, AutoCleanMemory.b = #True)
	Declare.b SetMesh(ResourceId$, Resource.i, Overwrite.b = #False, AutoCleanMemory.b = #True)
	Declare.b SetEntity(ResourceId$, Resource.i, Overwrite.b = #False, AutoCleanMemory.b = #True)
	Declare.b SetCamera(ResourceId$, Resource.i, Overwrite.b = #False, AutoCleanMemory.b = #True)
	
	Declare.b DeleteEntity(ResourceId$, CleanMemory.b = #True)
	Declare.b DeleteCamera(ResourceId$, CleanMemory.b = #True)
	
	Declare FlushTextures(CleanMemory.b = #True)
	Declare FlushMaterials(CleanMemory.b = #True)
	Declare FlushMeshes(CleanMemory.b = #True)
	Declare FlushEntities(CleanMemory.b = #True)
	Declare FlushCameras(CleanMemory.b = #True)
	Declare FlushAll(CleanMemory.b = #True)
EndDeclareModule

Module Resources
	EnableExplicit
	
	; This is more complicated than it should be because PB can be pretty retarded at times...
	Structure ResourceRegistration
		ResourceRealParrentPath$
		ResourceArchivePath$
		ResourceFilePath$
		ResourceKey$
		ResourceType.i
	EndStructure
	
	Enumeration ResourceTypes
		#ResourceType_Texture
		#ResourceType_Material
		#ResourceType_Mesh
		#ResourceType_Entity
		#ResourceType_Camera
	EndEnumeration
	
	#ResourceErrorKey$ = "error"
	
	; Could be grouped inside a single map, but it would decrease performances for no good reason.
	Global NewMap Textures.i()
	Global NewMap Materials.i()
	
	Global NewMap Meshes.i()
	Global NewMap Entities.i()
	
	Global NewMap Cameras.i()
	
	Global NewList UnloadedResources.ResourceRegistration()
	
	; The error resources are kept out of the maps for faster access
	;  and To protect them from being flushed.
	Global ErrorTexture, ErrorMaterial
	
	Procedure.b Init()
		; TODO: ???
	EndProcedure
	
	Procedure.b Start()
		Logger::Devel("Creating error resources...")
		
		; Texture
		If Not IsTexture(ErrorTexture)
			ErrorTexture = CreateTexture(#PB_Any, 2, 2)
			StartDrawing(TextureOutput(ErrorTexture))
			Box(0, 0, 2, 2, RGB(0, 0, 0))
			Box(1, 0, 1, 1, RGB(255, 0, 255))
			Box(0, 1, 1, 1, RGB(255, 0, 255))
			StopDrawing()
		EndIf
		
		; Material
		If Not IsMaterial(ErrorMaterial)
			ErrorMaterial = CreateMaterial(#PB_Any, TextureID(ErrorTexture))
			MaterialFilteringMode(ErrorMaterial, #PB_Material_None)
		EndIf
	EndProcedure
	
	Procedure.b Finish(CleanMemory.b = #True)
		FlushAll(CleanMemory)
		
		If CleanMemory
			FreeMaterial(ErrorMaterial)
			FreeTexture(ErrorTexture)
		EndIf
	EndProcedure
	
	Procedure.q ReadIndexFiles(RealParentFolder$, Folder$)
		Protected NewResourceCount.q = 0
		
		If Not (Right(RealParentFolder$, 1) = "/" Or Right(RealParentFolder$, 1) = "\")
			RealParentFolder$ = RealParentFolder$ + "/"
		EndIf
		
		If Not (Right(Folder$, 1) = "/" Or Right(Folder$, 1) = "\")
			Folder$ = Folder$ + "/"
		EndIf
		
		Logger::Devel("Searching for index files in: "+RealParentFolder$+Folder$)
		
		If FileSize(RealParentFolder$+Folder$ + "index-textures.json") > 0
			Protected TextureIndexJson
			
			TextureIndexJson = LoadJSON(#PB_Any, RealParentFolder$+Folder$ + "index-textures.json")
			
			If Not TextureIndexJson
				Logger::Error("Failed to load: "+RealParentFolder$+Folder$+"index-textures.json")
				Logger::Error("-> "+JSONErrorMessage()+" @ "+JSONErrorLine()+":"+JSONErrorPosition())
				ProcedureReturn NewResourceCount
			EndIf
			
			Logger::Devel("Found a texture index !")
			
			Protected NewMap TextureList.s()
			ExtractJSONMap(JSONValue(TextureIndexJson), TextureList())
			
			ForEach TextureList()
				If Left(MapKey(TextureList()), 1) = "_"
					Continue
				EndIf
				
				AddElement(UnloadedResources())
				UnloadedResources()\ResourceRealParrentPath$ = RealParentFolder$
				UnloadedResources()\ResourceArchivePath$ = Folder$
				UnloadedResources()\ResourceFilePath$ = TextureList()
				UnloadedResources()\ResourceKey$ = MapKey(TextureList())
				UnloadedResources()\ResourceType = #ResourceType_Texture
			Next
			
			FreeMap(TextureList())
			FreeJSON(TextureIndexJson)
		EndIf
		
		ProcedureReturn NewResourceCount
	EndProcedure
	
	Procedure.b Update()
		If ListSize(UnloadedResources()) > 0
			FirstElement(UnloadedResources())
			Logger::Devel("Loading ressource: "+UnloadedResources()\ResourceKey$)
			
			Select UnloadedResources()\ResourceType
				Case #ResourceType_Texture:
					Protected NewTexture = LoadTexture(#PB_Any, UnloadedResources()\ResourceArchivePath$ +
					                                            UnloadedResources()\ResourceFilePath$)
					
					If IsTexture(NewTexture)
						SetTexture(UnloadedResources()\ResourceKey$, NewTexture, #True, #True)
					Else
						Logger::Error("Failed to load texture !")
					EndIf
				Default:
					Logger::Error("Unknown resource type !!!")
			EndSelect
			
			DeleteElement(UnloadedResources())
			
			ProcedureReturn #False
		EndIf
		
		ProcedureReturn #True
	EndProcedure
	
	Procedure.b UpdateAll()
		While Not Update() : Wend
		ProcedureReturn #True
	EndProcedure
	
	
	;- Checkers
	
	Procedure.i HasResource(ResourceId$, ResourceType.i)
		If ResourceId$ <> #Null$
			Select ResourceType
				Case #ResourceType_Texture:
					ProcedureReturn FindMapElement(Textures(), ResourceId$)
				Case #ResourceType_Material:
					ProcedureReturn FindMapElement(Materials(), ResourceId$)
				Case #ResourceType_Mesh:
					ProcedureReturn FindMapElement(Meshes(), ResourceId$)
				Case #ResourceType_Entity:
					ProcedureReturn FindMapElement(Entities(), ResourceId$)
				Case #ResourceType_Camera:
					ProcedureReturn FindMapElement(Cameras(), ResourceId$)
			EndSelect
		EndIf
		
		ProcedureReturn #False
	EndProcedure
	
	Procedure.i HasTexture(ResourceId$)
		ProcedureReturn HasResource(ResourceId$, #ResourceType_Texture)
	EndProcedure
	
	Procedure.i HasMaterial(ResourceId$)
		ProcedureReturn HasResource(ResourceId$, #ResourceType_Material)
	EndProcedure
	
	Procedure.i HasMesh(ResourceId$)
		ProcedureReturn HasResource(ResourceId$, #ResourceType_Mesh)
	EndProcedure
	
	Procedure.i HasEntity(ResourceId$)
		ProcedureReturn HasResource(ResourceId$, #ResourceType_Entity)
	EndProcedure
	
	Procedure.i HasCamera(ResourceId$)
		ProcedureReturn HasResource(ResourceId$, #ResourceType_Camera)
	EndProcedure
	
	
	;- Getters
	
	Procedure.i GetTexture(ResourceId$)
		If ResourceId$ = #Null$ Or Not FindMapElement(Textures(), ResourceId$)
			ProcedureReturn ErrorTexture
		EndIf
		
		ProcedureReturn Textures(ResourceId$)
	EndProcedure
	
	Procedure.i GetMaterial(ResourceId$)
		If ResourceId$ = #Null$ Or Not FindMapElement(Materials(), ResourceId$)
			ProcedureReturn ErrorMaterial
		EndIf
		
		ProcedureReturn Materials(ResourceId$)
	EndProcedure
	
	Procedure.i GetMesh(ResourceId$)
		If ResourceId$ = #Null$ Or Not FindMapElement(Meshes(), ResourceId$)
			ProcedureReturn Meshes(#ResourceErrorKey$)
		EndIf
		
		ProcedureReturn Meshes(ResourceId$)
	EndProcedure
	
	Procedure.i GetEntity(ResourceId$)
		If ResourceId$ = #Null$ Or Not FindMapElement(Entities(), ResourceId$)
			ProcedureReturn Entities(#ResourceErrorKey$)
		EndIf
		
		ProcedureReturn Entities(ResourceId$)
	EndProcedure
	
	Procedure.i GetCamera(ResourceId$)
		If ResourceId$ = #Null$ Or Not FindMapElement(Cameras(), ResourceId$)
			ProcedureReturn Cameras(#ResourceErrorKey$)
		EndIf
		
		ProcedureReturn Cameras(ResourceId$)
	EndProcedure
	
	
	;- Setters
	
	Procedure.b SetTexture(ResourceId$, Resource.i, Overwrite.b = #False, CleanMemory.b = #True)
		If ResourceId$ <> #Null$
			If FindMapElement(Textures(), ResourceId$)
				If Overwrite
					If CleanMemory
						FreeTexture(Textures(ResourceId$))
					EndIf
				Else
					Logger::Error("Failed to register texture, key already exists: "+ResourceId$)
					ProcedureReturn #False
				EndIf
			EndIf
			
			Logger::Trace("Registered texture under: "+ResourceId$+" ("+Str(Resource)+")")
			Textures(ResourceId$) = Resource
			ProcedureReturn #True
		EndIf
		
		ProcedureReturn #False
	EndProcedure
	
	Procedure.b SetMaterial(ResourceId$, Resource.i, Overwrite.b = #False, CleanMemory.b = #True)
		If ResourceId$ <> #Null$
			If FindMapElement(Materials(), ResourceId$)
				If Overwrite
					If CleanMemory
						FreeTexture(Materials(ResourceId$))
					EndIf
				Else
					Logger::Error("Failed to register material, key already exists: "+ResourceId$)
					ProcedureReturn #False
				EndIf
			EndIf
			
			Materials(ResourceId$) = Resource
			ProcedureReturn #True
		EndIf
		
		ProcedureReturn #False
	EndProcedure
	
	Procedure.b SetMesh(ResourceId$, Resource.i, Overwrite.b = #False, CleanMemory.b = #True)
		If ResourceId$ <> #Null$
			If FindMapElement(Meshes(), ResourceId$)
				If Overwrite
					If CleanMemory
						FreeTexture(Meshes(ResourceId$))
					EndIf
				Else
					Logger::Error("Failed to register mesh, key already exists: "+ResourceId$)
					ProcedureReturn #False
				EndIf
			EndIf
			
			Meshes(ResourceId$) = Resource
			ProcedureReturn #True
		EndIf
		
		ProcedureReturn #False
	EndProcedure
	
	Procedure.b SetEntity(ResourceId$, Resource.i, Overwrite.b = #False, CleanMemory.b = #True)
		If ResourceId$ <> #Null$
			If FindMapElement(Entities(), ResourceId$)
				If Overwrite
					If CleanMemory
						FreeTexture(Entities(ResourceId$))
					EndIf
				Else
					Logger::Error("Failed to register entity, key already exists: "+ResourceId$)
					ProcedureReturn #False
				EndIf
			EndIf
			
			Entities(ResourceId$) = Resource
			ProcedureReturn #True
		EndIf
		
		ProcedureReturn #False
	EndProcedure
	
	Procedure.b SetCamera(ResourceId$, Resource.i, Overwrite.b = #False, CleanMemory.b = #True)
		If ResourceId$ <> #Null$
			If FindMapElement(Cameras(), ResourceId$)
				If Overwrite
					If CleanMemory
						FreeTexture(Cameras(ResourceId$))
					EndIf
				Else
					Logger::Error("Failed to register camera, key already exists: "+ResourceId$)
					ProcedureReturn #False
				EndIf
			EndIf
			
			Cameras(ResourceId$) = Resource
			ProcedureReturn #True
		EndIf
		
		ProcedureReturn #False
	EndProcedure
	
	
	;- Deleters
	
	Procedure.b DeleteEntity(ResourceId$, CleanMemory.b = #True)
		If ResourceId$ <> #Null$
			Protected Resource = FindMapElement(Entities(), ResourceId$)
			
			If Resource
				If CleanMemory
					FreeEntity(Resource)
				EndIf
				
				DeleteMapElement(Entities(), ResourceId$) 
			EndIf
		EndIf
	EndProcedure
	
	Procedure.b DeleteCamera(ResourceId$, CleanMemory.b = #True)
		If ResourceId$ <> #Null$
			Protected Resource = FindMapElement(Cameras(), ResourceId$)
			
			If Resource
				If CleanMemory
					FreeCamera(Resource)
				EndIf
				
				DeleteMapElement(Cameras(), ResourceId$) 
			EndIf
		EndIf
	EndProcedure
	
	
	;- Flushers
	
	Procedure FlushTextures(CleanMemory.b = #True)
		If CleanMemory
			ForEach Textures()
				FreeTexture(Textures())
			Next
		EndIf
		
		ClearMap(Textures())
	EndProcedure
	
	Procedure FlushMaterials(CleanMemory.b = #True)
		If CleanMemory
			ForEach Materials()
				FreeMaterial(Materials())
			Next
		EndIf
		
		ClearMap(Materials())
	EndProcedure
	
	Procedure FlushMeshes(CleanMemory.b = #True)
		If CleanMemory
			ForEach Meshes()
				FreeMesh(Meshes())
			Next
		EndIf
		
		ClearMap(Meshes())
	EndProcedure
	
	Procedure FlushEntities(CleanMemory.b = #True)
		If CleanMemory
			ForEach Entities()
				FreeEntity(Entities())
			Next
		EndIf
		
		ClearMap(Entities())
	EndProcedure
	
	Procedure FlushCameras(CleanMemory.b = #True)
		If CleanMemory
			ForEach Cameras()
				FreeCamera(Cameras())
			Next
		EndIf
		
		ClearMap(Cameras())
	EndProcedure
	
	Procedure FlushAll(CleanMemory.b = #True)
		FlushCameras(CleanMemory)
		FlushEntities(CleanMemory)
		FlushMeshes(CleanMemory)
		FlushMaterials(CleanMemory)
		FlushTextures(CleanMemory)
	EndProcedure
EndModule
