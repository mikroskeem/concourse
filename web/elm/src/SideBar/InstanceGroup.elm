module SideBar.InstanceGroup exposing (instanceGroup)

import Concourse
import HoverState
import Message.Message exposing (DomID(..), Message(..), PipelinesSection(..))
import Routes
import SideBar.Styles as Styles
import SideBar.Views as Views


type alias PipelineScoped a =
    { a
        | teamName : String
        , pipelineName : String
    }


instanceGroup :
    { a
        | hovered : HoverState.HoverState
        , currentPipeline : Maybe (PipelineScoped b)
        , isFavoritesSection : Bool
    }
    -> Concourse.Pipeline
    -> List Concourse.Pipeline
    -> Views.InstanceGroup
instanceGroup params p ps =
    let
        isCurrent =
            case params.currentPipeline of
                Just cp ->
                    List.any
                        (\pipeline ->
                            cp.pipelineName == pipeline.name && cp.teamName == pipeline.teamName
                        )
                        (p :: ps)

                Nothing ->
                    False

        domID =
            SideBarInstanceGroup
                (if params.isFavoritesSection then
                    FavoritesSection

                 else
                    AllPipelinesSection
                )
                p.teamName
                p.name

        isHovered =
            HoverState.isHovered domID params.hovered

        color =
            if isHovered then
                Styles.White

            else if isCurrent then
                Styles.LightGrey

            else
                Styles.Grey
    in
    { name =
        { color = color
        , text = p.name
        , weight =
            if isCurrent then
                Styles.Bold

            else
                Styles.Default
        }
    , background =
        if isCurrent then
            Styles.Dark

        else if isHovered then
            Styles.Light

        else
            Styles.Invisible
    , href =
        Routes.toString <|
            Routes.Dashboard
                { searchType = Routes.Normal "" <| Just { teamName = p.teamName, name = p.name }
                , dashboardView = Routes.ViewNonArchivedPipelines
                }
    , domID = domID
    , badge =
        { count = List.length (p :: ps)
        , color = color
        }
    }
